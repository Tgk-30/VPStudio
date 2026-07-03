import Foundation
import Testing
@testable import VPStudio

@Suite("Library Action Row Policy")
struct LibraryActionRowPolicyTests {
    @Test
    func actionOrderIsStable() {
        let actions = LibraryActionRowPolicy.actions(selectedList: .watchlist, isRefreshing: false)
        #expect(actions.map(\.kind) == [.sort, .export, .import, .refresh])
    }

    @Test
    func refreshIsAvailableForWatchlistWhenIdle() {
        let refresh = LibraryActionRowPolicy.actions(selectedList: .watchlist, isRefreshing: false).last

        #expect(refresh?.kind == .refresh)
        #expect(refresh?.title == "Refresh")
        #expect(refresh?.systemImage == "arrow.clockwise")
        #expect(refresh?.isEnabled == true)
    }

    @Test
    func refreshIsDisabledForHistory() {
        let refresh = LibraryActionRowPolicy.actions(selectedList: .history, isRefreshing: false).last

        #expect(refresh?.kind == .refresh)
        #expect(refresh?.title == "Refresh")
        #expect(refresh?.isEnabled == false)
    }

    @Test
    func refreshShowsProgressStateWhileRefreshing() {
        let refresh = LibraryActionRowPolicy.actions(selectedList: .favorites, isRefreshing: true).last

        #expect(refresh?.kind == .refresh)
        #expect(refresh?.title == "Refreshing...")
        #expect(refresh?.systemImage == "hourglass")
        #expect(refresh?.isEnabled == false)
    }
}

@Suite("Library Title Refresh Policy")
struct LibraryTitleRefreshPolicyTests {
    @Test
    func refreshingMessageIncludesSelectedListName() {
        #expect(
            LibraryTitleRefreshPolicy.refreshingMessage(for: .watchlist)
                == "Refreshing title matches in Watchlist..."
        )
        #expect(
            LibraryTitleRefreshPolicy.refreshingMessage(for: .favorites)
                == "Refreshing title matches in Favorites..."
        )
    }

    @Test
    func completionMessageUsesSingularPluralAndZeroForms() {
        #expect(
            LibraryTitleRefreshPolicy.completionMessage(for: .watchlist, removedCount: 0)
                == "Refresh complete: no duplicate titles found in Watchlist."
        )
        #expect(
            LibraryTitleRefreshPolicy.completionMessage(for: .watchlist, removedCount: 1)
                == "Refresh complete: merged 1 duplicate title in Watchlist."
        )
        #expect(
            LibraryTitleRefreshPolicy.completionMessage(for: .watchlist, removedCount: 4)
                == "Refresh complete: merged 4 duplicate titles in Watchlist."
        )
    }
}

@Suite("Library Feedback Presentation Policy")
struct LibraryFeedbackPresentationPolicyTests {
    @Test
    func actionErrorTakesPrecedenceOverStatusCopy() {
        let appError = AppError.unknown("Couldn't move this title right now.")

        #expect(
            LibraryFeedbackPresentationPolicy.message(
                statusMessage: "Moved to Sci-Fi.",
                actionError: appError
            ) == .error(appError)
        )
    }

    @Test
    func statusCopyShowsWhenNoActionErrorExists() {
        #expect(
            LibraryFeedbackPresentationPolicy.message(
                statusMessage: "Folder order updated.",
                actionError: nil
            ) == .status("Folder order updated.")
        )

        #expect(
            LibraryFeedbackPresentationPolicy.message(
                statusMessage: nil,
                actionError: nil
            ) == nil
        )
    }

    @Test
    func libraryActionFailurePolicyProvidesReadableFallbackCopy() {
        let sampleError = NSError(domain: "VPStudioTests", code: 1)

        #expect(
            LibraryActionFailurePolicy.appError(
                for: sampleError,
                action: .createFolder
            ).errorDescription == "Couldn't create the folder."
        )

        #expect(
            LibraryActionFailurePolicy.appError(
                for: sampleError,
                action: .refreshTitles(listName: "Watchlist")
            ).errorDescription == "Couldn't refresh duplicate titles in Watchlist."
        )

        #expect(
            LibraryActionFailurePolicy.appError(
                for: sampleError,
                action: .removeTitle(listName: "Favorites")
            ).errorDescription == "Couldn't remove this title from Favorites."
        )

        #expect(
            LibraryActionFailurePolicy.appError(
                for: sampleError,
                action: .moveTitle
            ).errorDescription == "Couldn't move this title right now."
        )

        #expect(
            LibraryActionFailurePolicy.appError(
                for: sampleError,
                action: .reorderFolders
            ).errorDescription == "Couldn't save the new folder order."
        )

        #expect(
            LibraryActionFailurePolicy.appError(
                for: sampleError,
                action: .deleteFolder
            ).errorDescription == "Couldn't delete this folder."
        )
    }

    @Test
    func libraryHeaderActionKindIDsMatchRawValues() {
        for kind in LibraryHeaderActionKind.allCases {
            #expect(kind.id == kind.rawValue)
        }
    }
}

@Suite("Library Rating Alias Loading")
struct LibraryRatingAliasLoadingTests {
    @Test
    func libraryBuildsUserRatingsWithCachedMediaAliases() throws {
        let source = try contents(of: "VPStudio/Views/Windows/Library/LibraryView.swift")

        #expect(source.contains("async let eventsLoad = appState.database.fetchTasteEvents(eventType: .rated, limit: 500)"))
        #expect(source.contains("async let aliasItemsLoad = appState.database.fetchMediaItemsForTasteRatingAliases()"))
        #expect(source.contains("userRatings = TasteRatingLookupPolicy.lookup(from: events, mediaItems: aliasItems)"))
    }

    private func contents(of relativePath: String) throws -> String {
        let absolutePath = repoRootURL().appendingPathComponent(relativePath).path
        return try String(contentsOfFile: absolutePath, encoding: .utf8)
    }

    private func repoRootURL() -> URL {
        var url = URL(fileURLWithPath: #filePath)
        while url.lastPathComponent != "VPStudioTests" {
            let parent = url.deletingLastPathComponent()
            if parent.path == url.path { break }
            url = parent
        }
        return url.deletingLastPathComponent()
    }
}

@Suite("Library Import Outcome Policy")
struct LibraryImportOutcomePolicyTests {
    @Test
    func displayedHistoryMediaIDsDeduplicatesWhilePreservingFirstOccurrence() {
        let history = [
            makeHistory(id: "h1", mediaId: "tt001"),
            makeHistory(id: "h2", mediaId: "tt002"),
            makeHistory(id: "h3", mediaId: "tt001"),
            makeHistory(id: "h4", mediaId: "tt003"),
        ]

        #expect(LibraryImportOutcomePolicy.displayedHistoryMediaIDs(from: history) == ["tt001", "tt002", "tt003"])
    }

    @Test
    func preferredListTypePrefersWatchlistThenFavoritesThenHistory() {
        #expect(
            LibraryImportOutcomePolicy.preferredListType(
                after: makeSummary(watchlist: 1, favorites: 1, history: 1)
            ) == .watchlist
        )
        #expect(
            LibraryImportOutcomePolicy.preferredListType(
                after: makeSummary(watchlist: 0, favorites: 2, history: 1)
            ) == .favorites
        )
        #expect(
            LibraryImportOutcomePolicy.preferredListType(
                after: makeSummary(watchlist: 0, favorites: 0, history: 3)
            ) == .history
        )
        #expect(
            LibraryImportOutcomePolicy.preferredListType(
                after: makeSummary(watchlist: 0, favorites: 0, history: 0)
            ) == nil
        )
    }

    @Test
    func importStatusMessageReportsRatingsOnlyWhenNoLibraryRowsChanged() {
        #expect(
            LibraryImportOutcomePolicy.importStatusMessage(
                from: makeSummary(watchlist: 0, favorites: 0, history: 0, ratings: 4)
            ) == "Import finished: no new library items, but 4 ratings were imported."
        )
    }

    @Test
    func importStatusMessageReportsNoLibraryRowsChanged() {
        #expect(
            LibraryImportOutcomePolicy.importStatusMessage(
                from: makeSummary(watchlist: 0, favorites: 0, history: 0, ratings: 0)
            ) == "Import finished: no new library items were added."
        )
    }

    @Test
    func importStatusMessageReportsMergedLibraryCounts() {
        #expect(
            LibraryImportOutcomePolicy.importStatusMessage(
                from: makeSummary(watchlist: 2, favorites: 3, history: 4, rowsImported: 9)
            ) == "Import added W:2 F:3 H:4 from 9 rows. Repeated IMDb IDs across files were merged."
        )
    }

    private func makeHistory(id: String, mediaId: String) -> WatchHistory {
        WatchHistory(
            id: id,
            mediaId: mediaId,
            title: "Title \(mediaId)",
            progress: 10,
            duration: 100,
            watchedAt: Date(timeIntervalSince1970: 0),
            isCompleted: false
        )
    }

    private func makeSummary(
        watchlist: Int,
        favorites: Int,
        history: Int,
        ratings: Int = 0,
        rowsImported: Int = 0
    ) -> LibraryCSVImportSummary {
        LibraryCSVImportSummary(
            detectedFormat: .generic,
            rowsRead: rowsImported,
            rowsImported: rowsImported,
            rowsSkipped: 0,
            mediaItemsCreated: 0,
            mediaItemsUpdated: 0,
            watchlistImported: watchlist,
            favoritesImported: favorites,
            historyImported: history,
            ratingsImported: ratings,
            targetFolderID: nil,
            targetFolderName: nil
        )
    }
}

@Suite("Library Metadata Hydration Policy")
struct LibraryMetadataHydrationPolicyTests {
    @Test
    func candidatesDeduplicateRequestedIDsAndUseTMDBForLegacyTMDBItems() {
        let movie = mediaItem(
            id: "movie-local",
            type: .movie,
            title: "Fight Club",
            tmdbId: 550
        )

        let candidates = LibraryMetadataHydrationPolicy.candidates(
            for: ["movie-local", "movie-local"],
            mediaItems: ["movie-local": movie]
        )

        #expect(candidates == [
            .init(requestedID: "movie-local", detailID: "tmdb-550", type: .movie, knownTMDBID: 550),
        ])
    }

    @Test
    func candidatesPreferOMDbTitleLookupWhenOMDbIsConfigured() {
        let movie = mediaItem(
            id: "movie-local",
            type: .movie,
            title: "Fight Club",
            year: 1999,
            tmdbId: 550
        )

        let candidates = LibraryMetadataHydrationPolicy.candidates(
            for: ["movie-local"],
            mediaItems: ["movie-local": movie],
            allowsTMDbIdentifier: true,
            prefersOMDbTitleLookup: true
        )

        #expect(candidates == [
            .init(requestedID: "movie-local", detailID: "Fight Club (1999)", type: .movie, knownTMDBID: 550),
        ])
    }

    @Test
    func candidatesUseTitleForLegacyTMDBItemsWhenTMDBIsUnavailable() {
        let movie = mediaItem(
            id: "movie-local",
            type: .movie,
            title: "Fight Club",
            tmdbId: 550
        )

        let candidates = LibraryMetadataHydrationPolicy.candidates(
            for: ["movie-local"],
            mediaItems: ["movie-local": movie],
            allowsTMDbIdentifier: false
        )

        #expect(candidates == [
            .init(requestedID: "movie-local", detailID: "Fight Club", type: .movie, knownTMDBID: 550),
        ])
    }

    @Test
    func candidatesPreferEmbeddedIMDbIDOverTitleAndTMDBID() {
        let movie = mediaItem(
            id: "movie-imdb-tt0133093",
            type: .movie,
            title: "The Matrix",
            tmdbId: 603
        )

        let candidates = LibraryMetadataHydrationPolicy.candidates(
            for: ["local-matrix"],
            mediaItems: ["local-matrix": movie]
        )

        #expect(candidates == [
            .init(requestedID: "local-matrix", detailID: "tt0133093", type: .movie, knownTMDBID: 603),
        ])
    }

    @Test
    func candidatesSkipItemsThatAlreadyHaveArtwork() {
        let withPoster = mediaItem(
            id: "movie-with-poster",
            posterPath: "/poster.jpg",
            tmdbId: 550
        )
        let withBackdrop = mediaItem(
            id: "movie-with-backdrop",
            backdropPath: "/backdrop.jpg",
            tmdbId: 551
        )

        let candidates = LibraryMetadataHydrationPolicy.candidates(
            for: ["movie-with-poster", "movie-with-backdrop"],
            mediaItems: [
                "movie-with-poster": withPoster,
                "movie-with-backdrop": withBackdrop,
            ]
        )

        #expect(candidates.isEmpty)
    }

    @Test
    func candidatesFallbackToIMDbItemIDThenRequestedIDThenTitle() {
        let imdbItem = mediaItem(id: "tt0133093", type: .movie)
        let aliasItem = mediaItem(id: "local-alias", type: .series)
        let tmdbAliasItem = mediaItem(id: "series-tmdb-1399", type: .series)

        let candidates = LibraryMetadataHydrationPolicy.candidates(
            for: ["tt0133093", "tt-series-alias", "series-tmdb-1399"],
            mediaItems: [
                "tt0133093": imdbItem,
                "tt-series-alias": aliasItem,
                "series-tmdb-1399": tmdbAliasItem,
            ]
        )

        #expect(candidates == [
            .init(requestedID: "tt0133093", detailID: "tt0133093", type: .movie),
            .init(requestedID: "tt-series-alias", detailID: "Title local-alias", type: .series),
            .init(requestedID: "series-tmdb-1399", detailID: "tmdb-1399", type: .series, knownTMDBID: 1399),
        ])
    }

    @Test
    func candidatesIgnoreMissingAndUnresolvableItems() {
        // Genuinely unresolvable: no IMDb/TMDb id AND no title to search by
        // (a title is itself a resolution path — see candidatesFallbackTo…Title).
        let localItem = mediaItem(id: "local-only", type: .movie, title: "")

        let candidates = LibraryMetadataHydrationPolicy.candidates(
            for: ["missing", "local-only"],
            mediaItems: ["local-only": localItem]
        )

        #expect(candidates.isEmpty)
    }

    @Test
    func shouldPersistWhenTypeMatchesAndTMDBIDAgrees() {
        #expect(LibraryMetadataHydrationPolicy.shouldPersist(
            hydratedType: .series,
            hydratedTMDBID: 276161,
            requestedType: .series,
            knownTMDBID: 276161
        ))
    }

    @Test
    func shouldPersistWhenNoTMDBIDIsKnownYet() {
        #expect(LibraryMetadataHydrationPolicy.shouldPersist(
            hydratedType: .movie,
            hydratedTMDBID: 438631,
            requestedType: .movie,
            knownTMDBID: nil
        ))
    }

    @Test
    func shouldRejectCrossTypeHydrationOverwrite() {
        #expect(!LibraryMetadataHydrationPolicy.shouldPersist(
            hydratedType: .movie,
            hydratedTMDBID: 896977,
            requestedType: .series,
            knownTMDBID: 276161
        ))
    }

    @Test
    func shouldRejectConflictingTMDBIdentity() {
        #expect(!LibraryMetadataHydrationPolicy.shouldPersist(
            hydratedType: .series,
            hydratedTMDBID: 896977,
            requestedType: .series,
            knownTMDBID: 276161
        ))
    }

    private func mediaItem(
        id: String,
        type: MediaType = .movie,
        title: String? = nil,
        year: Int? = nil,
        posterPath: String? = nil,
        backdropPath: String? = nil,
        tmdbId: Int? = nil
    ) -> MediaItem {
        MediaItem(
            id: id,
            type: type,
            title: title ?? "Title \(id)",
            year: year,
            posterPath: posterPath,
            backdropPath: backdropPath,
            tmdbId: tmdbId
        )
    }
}

@Suite("Library Folder Label Policy")
struct LibraryFolderLabelPolicyTests {
    @Test
    func systemRootUsesTopLevelTitle() {
        let root = makeFolder(
            id: LibraryFolder.systemFolderID(for: .watchlist),
            name: "Watchlist",
            parentId: nil,
            listType: .watchlist,
            folderKind: .systemRoot,
            isSystem: true
        )

        #expect(LibraryFolderLabelPolicy.chipTitle(for: root, in: [root]) == "Unsorted")
        #expect(LibraryFolderLabelPolicy.fullPath(for: root, in: [root]) == "Unsorted")
    }

    @Test
    func manualFolderUnderSystemRootKeepsSimpleName() {
        let root = makeFolder(
            id: LibraryFolder.systemFolderID(for: .favorites),
            name: "Favorites",
            parentId: nil,
            listType: .favorites,
            folderKind: .systemRoot,
            isSystem: true
        )
        let child = makeFolder(
            id: "manual-sci-fi",
            name: "Sci-Fi",
            parentId: root.id,
            listType: .favorites
        )

        #expect(LibraryFolderLabelPolicy.chipTitle(for: child, in: [root, child]) == "Sci-Fi")
    }

    @Test
    func manualChildFolderIncludesParentBreadcrumb() {
        let root = makeFolder(
            id: LibraryFolder.systemFolderID(for: .watchlist),
            name: "Watchlist",
            parentId: nil,
            listType: .watchlist,
            folderKind: .systemRoot,
            isSystem: true
        )
        let parent = makeFolder(
            id: "anime",
            name: "Anime",
            parentId: root.id,
            listType: .watchlist
        )
        let child = makeFolder(
            id: "spring-2026",
            name: "Spring 2026",
            parentId: parent.id,
            listType: .watchlist
        )

        #expect(LibraryFolderLabelPolicy.chipTitle(for: child, in: [root, parent, child]) == "Anime › Spring 2026")
    }

    @Test
    func multiLevelHierarchyProducesFullReadablePath() {
        let root = makeFolder(
            id: LibraryFolder.systemFolderID(for: .favorites),
            name: "Favorites",
            parentId: nil,
            listType: .favorites,
            folderKind: .systemRoot,
            isSystem: true
        )
        let parent = makeFolder(id: "marvel", name: "Marvel", parentId: root.id, listType: .favorites)
        let child = makeFolder(id: "phase-1", name: "Phase 1", parentId: parent.id, listType: .favorites)
        let grandchild = makeFolder(id: "origins", name: "Origins", parentId: child.id, listType: .favorites)

        #expect(
            LibraryFolderLabelPolicy.fullPath(for: grandchild, in: [root, parent, child, grandchild])
                == "Marvel › Phase 1 › Origins"
        )
    }

    @Test
    func duplicateChildNamesAreDisambiguatedByParentPath() {
        let root = makeFolder(
            id: LibraryFolder.systemFolderID(for: .watchlist),
            name: "Watchlist",
            parentId: nil,
            listType: .watchlist,
            folderKind: .systemRoot,
            isSystem: true
        )
        let movies = makeFolder(id: "movies", name: "Movies", parentId: root.id, listType: .watchlist)
        let tv = makeFolder(id: "tv", name: "TV", parentId: root.id, listType: .watchlist)
        let moviesFavorites = makeFolder(id: "movies-favorites", name: "Favorites", parentId: movies.id, listType: .watchlist)
        let tvFavorites = makeFolder(id: "tv-favorites", name: "Favorites", parentId: tv.id, listType: .watchlist)
        let folders = [root, movies, tv, moviesFavorites, tvFavorites]

        #expect(LibraryFolderLabelPolicy.chipTitle(for: moviesFavorites, in: folders) == "Movies › Favorites")
        #expect(LibraryFolderLabelPolicy.chipTitle(for: tvFavorites, in: folders) == "TV › Favorites")
    }

    @Test
    func missingParentFallsBackToFolderName() {
        let orphan = makeFolder(
            id: "orphan",
            name: "Loose Ends",
            parentId: "missing-parent",
            listType: .favorites
        )

        #expect(LibraryFolderLabelPolicy.chipTitle(for: orphan, in: [orphan]) == "Loose Ends")
    }

    @Test
    func cyclicParentChainsDoNotInfiniteLoopAndProvideStableBreadcrumbs() {
        let a = makeFolder(
            id: "a",
            name: "A",
            parentId: "b",
            listType: .watchlist
        )
        let b = makeFolder(
            id: "b",
            name: "B",
            parentId: "a",
            listType: .watchlist
        )

        // The policy intentionally stops when it detects a cycle, so we expect a best-effort path.
        #expect(LibraryFolderLabelPolicy.fullPath(for: a, in: [a, b]) == "B › A")
        #expect(LibraryFolderLabelPolicy.fullPath(for: b, in: [a, b]) == "A › B")
    }

    @Test
    func orderedUserFoldersRespectsManualOrderAndAppendsMissingFolders() {
        let alpha = makeFolder(id: "alpha", name: "Alpha", listType: .watchlist)
        let beta = makeFolder(id: "beta", name: "Beta", listType: .watchlist)
        let gamma = makeFolder(id: "gamma", name: "Gamma", listType: .watchlist)

        let ordered = LibraryFolderSelectionPolicy.orderedUserFolders(
            [alpha, beta, gamma],
            manualFolderOrderIDs: ["gamma", "missing", "alpha"]
        )

        #expect(ordered.map(\.id) == ["gamma", "alpha", "beta"])
    }

    @Test
    func orderedUserFoldersFallsBackToNaturalOrderWhenManualOrderIsEmpty() {
        let alpha = makeFolder(id: "alpha", name: "Alpha", listType: .favorites)
        let beta = makeFolder(id: "beta", name: "Beta", listType: .favorites)

        #expect(
            LibraryFolderSelectionPolicy.orderedUserFolders(
                [alpha, beta],
                manualFolderOrderIDs: []
            ).map(\.id) == ["alpha", "beta"]
        )
    }

    @Test
    func selectedFolderIDAfterReloadKeepsLoadedSelectionAndClearsStaleSelection() {
        let alpha = makeFolder(id: "alpha", name: "Alpha", listType: .watchlist)
        let beta = makeFolder(id: "beta", name: "Beta", listType: .watchlist)

        #expect(
            LibraryFolderSelectionPolicy.selectedFolderIDAfterReload(
                loadedFolders: [alpha, beta],
                currentSelection: "beta"
            ) == "beta"
        )
        #expect(
            LibraryFolderSelectionPolicy.selectedFolderIDAfterReload(
                loadedFolders: [alpha],
                currentSelection: "beta"
            ) == nil
        )
        #expect(
            LibraryFolderSelectionPolicy.selectedFolderIDAfterReload(
                loadedFolders: [alpha],
                currentSelection: nil
            ) == nil
        )
    }

    @Test
    func manualFolderOrderIDsAfterReloadingExcludesSystemFolders() {
        let root = makeFolder(
            id: LibraryFolder.systemFolderID(for: .watchlist),
            name: "Watchlist",
            listType: .watchlist,
            folderKind: .systemRoot,
            isSystem: true
        )
        let alpha = makeFolder(id: "alpha", name: "Alpha", listType: .watchlist)
        let beta = makeFolder(id: "beta", name: "Beta", listType: .watchlist)

        #expect(
            LibraryFolderSelectionPolicy.manualFolderOrderIDs(afterReloading: [root, alpha, beta])
                == ["alpha", "beta"]
        )
    }

    private func makeFolder(
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
            isSystem: isSystem,
            sortOrder: 0,
            createdAt: Date(timeIntervalSince1970: 0),
            updatedAt: Date(timeIntervalSince1970: 0)
        )
    }
}
