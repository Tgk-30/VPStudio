import Foundation

/// Coordinates bi-directional sync between Trakt and the local database.
///
/// **Pull (Trakt -> Local):**
/// - Watchlist items become `UserLibraryEntry(listType: .watchlist)`
/// - Ratings become `TasteEvent(eventType: .rated)` with 1-10 scale
/// - History items become `WatchHistory` records (isCompleted=true) **and**
///   `UserLibraryEntry(listType: .history)` for backwards compatibility.
///   Pull paginates until Trakt returns a short page by default.
///
/// **Push (Local -> Trakt):**
/// - Local watchlist entries with IMDb IDs are added to Trakt watchlist
/// - Local rated taste events are pushed as Trakt ratings
/// - Completed local `WatchHistory` entries with IMDb IDs are pushed to Trakt history
///
/// The orchestrator is resilient: individual operation failures are logged in
/// `SyncResult.errors` rather than thrown, so a single Trakt API failure does
/// not prevent other sync operations from completing.
actor TraktSyncOrchestrator {
    private let traktService: TraktSyncService
    private let database: DatabaseManager
    private let settingsManager: SettingsManager

    init(
        traktService: TraktSyncService,
        database: DatabaseManager,
        settingsManager: SettingsManager,
        maxHistoryPages: Int? = defaultMaxHistoryPages
    ) {
        self.traktService = traktService
        self.database = database
        self.settingsManager = settingsManager
        self.maxPages = maxHistoryPages.flatMap { $0 > 0 ? $0 : nil }
    }

    /// Performs a full bi-directional sync based on current toggle settings.
    func sync() async -> SyncResult {
        var result = SyncResult()
        var attemptedEnabledOperation = false
        var completedMeaningfulOperation = false

        guard !isCancellationRequested else { return result }

        let syncWatchlist = (try? await settingsManager.getBool(
            key: SettingsKeys.traktSyncWatchlist, default: true
        )) ?? true

        let syncHistory = (try? await settingsManager.getBool(
            key: SettingsKeys.traktSyncHistory, default: true
        )) ?? true

        let syncRatings = (try? await settingsManager.getBool(
            key: SettingsKeys.traktSyncRatings, default: true
        )) ?? true

        // --- Pull ---

        if syncWatchlist {
            guard !isCancellationRequested else { return result }
            attemptedEnabledOperation = true
            let pullResult = await pullWatchlist()
            result.watchlistPulled = pullResult.count
            result.errors.append(contentsOf: pullResult.errors)
            result.localRefreshTargets.formUnion(pullResult.localRefreshTargets)
            completedMeaningfulOperation = completedMeaningfulOperation || pullResult.shouldAdvanceLastSyncDate
        }

        if syncRatings {
            guard !isCancellationRequested else { return result }
            attemptedEnabledOperation = true
            let pullResult = await pullRatings()
            result.ratingsPulled = pullResult.count
            result.errors.append(contentsOf: pullResult.errors)
            result.localRefreshTargets.formUnion(pullResult.localRefreshTargets)
            completedMeaningfulOperation = completedMeaningfulOperation || pullResult.shouldAdvanceLastSyncDate
        }

        if syncHistory {
            guard !isCancellationRequested else { return result }
            attemptedEnabledOperation = true
            let pullResult = await pullHistory()
            result.historyPulled = pullResult.count
            result.errors.append(contentsOf: pullResult.errors)
            result.localRefreshTargets.formUnion(pullResult.localRefreshTargets)
            completedMeaningfulOperation = completedMeaningfulOperation || pullResult.shouldAdvanceLastSyncDate
        }

        // --- Push ---

        if syncWatchlist {
            guard !isCancellationRequested else { return result }
            attemptedEnabledOperation = true
            let pushResult = await pushWatchlist()
            result.watchlistPushed = pushResult.count
            result.errors.append(contentsOf: pushResult.errors)
            completedMeaningfulOperation = completedMeaningfulOperation || pushResult.shouldAdvanceLastSyncDate
        }

        if syncRatings {
            guard !isCancellationRequested else { return result }
            attemptedEnabledOperation = true
            let pushResult = await pushRatings()
            result.ratingsPushed = pushResult.count
            result.errors.append(contentsOf: pushResult.errors)
            completedMeaningfulOperation = completedMeaningfulOperation || pushResult.shouldAdvanceLastSyncDate
        }

        if syncHistory {
            guard !isCancellationRequested else { return result }
            attemptedEnabledOperation = true
            let pushResult = await pushHistory()
            result.historyPushed = pushResult.count
            result.errors.append(contentsOf: pushResult.errors)
            completedMeaningfulOperation = completedMeaningfulOperation || pushResult.shouldAdvanceLastSyncDate
        }

        // --- Folders (bi-directional, uses Trakt custom lists) ---

        let syncFolders = (try? await settingsManager.getBool(
            key: SettingsKeys.traktSyncFolders, default: false
        )) ?? false

        if syncFolders {
            guard !isCancellationRequested else { return result }
            attemptedEnabledOperation = true
            let folderResult = await syncCustomLists()
            result.foldersPulled = folderResult.pulled
            result.foldersPushed = folderResult.pushed
            result.errors.append(contentsOf: folderResult.errors)
            result.localRefreshTargets.formUnion(folderResult.localRefreshTargets)
            completedMeaningfulOperation = completedMeaningfulOperation || folderResult.shouldAdvanceLastSyncDate
        }

        // Keep the last-sync marker useful even when part of the sync failed.
        // If at least one enabled operation completed meaningfully, or nothing
        // was enabled at all, advance the marker while still surfacing errors.
        if !isCancellationRequested, completedMeaningfulOperation || !attemptedEnabledOperation {
            let formatter = ISO8601DateFormatter()
            try? await settingsManager.setString(
                key: SettingsKeys.traktLastSyncDate,
                value: formatter.string(from: Date())
            )
        }

        return result
    }

    // MARK: - Pull Operations

    private func pullWatchlist() async -> OperationResult {
        var created = 0
        var errors: [String] = []
        var localRefreshTargets: SyncResult.LocalRefreshTargets = []

        for mediaType in [MediaType.movie, MediaType.series] {
            guard !isCancellationRequested else {
                return OperationResult(
                    count: created,
                    errors: errors,
                    localRefreshTargets: localRefreshTargets
                )
            }
            let items: [TraktItem]
            switch await collectRemotePages(
                resource: "Remote Trakt \(mediaType.rawValue) watchlist pull",
                fetchPage: { [self] page in
                    try await self.traktService.getWatchlist(type: mediaType, page: page)
                }
            ) {
            case .success(let fetchedItems):
                items = fetchedItems
            case .cancelled:
                return OperationResult(
                    count: created,
                    errors: errors,
                    localRefreshTargets: localRefreshTargets
                )
            case .failure(let error):
                errors.append(error)
                continue
            }

            for item in items {
                guard !isCancellationRequested else {
                    return OperationResult(
                        count: created,
                        errors: errors,
                        localRefreshTargets: localRefreshTargets
                    )
                }
                guard let remoteMediaId = extractMediaId(from: item) else { continue }
                do {
                    let mediaId = try await canonicalLocalMediaId(for: remoteMediaId)
                    let exists = try await database.isInLibrary(
                        mediaId: mediaId, listType: .watchlist
                    )
                    if !exists {
                        let entry = UserLibraryEntry(
                            id: UUID().uuidString,
                            mediaId: mediaId,
                            folderId: LibraryFolder.systemFolderID(for: .watchlist),
                            listType: .watchlist,
                            addedAt: Date()
                        )
                        try await database.addToLibrary(entry)
                        created += 1
                        localRefreshTargets.insert(.library)
                    }
                    // Ensure a stub MediaItem exists so LibraryView can display it
                    if (try? await ensureMediaItem(from: item, mediaId: mediaId)) == true {
                        localRefreshTargets.insert(.library)
                    }
                } catch {
                    if isCancellationError(error) {
                        return OperationResult(
                            count: created,
                            errors: errors,
                            localRefreshTargets: localRefreshTargets
                        )
                    }
                    errors.append(Self.sanitizedSyncError(prefix: "Pull watchlist entry \(remoteMediaId)", error: error))
                }
            }
        }

        return OperationResult(
            count: created,
            errors: errors,
            localRefreshTargets: localRefreshTargets
        )
    }

    private func pullRatings() async -> OperationResult {
        var createdOrUpdated = 0
        var errors: [String] = []
        var localRefreshTargets: SyncResult.LocalRefreshTargets = []

        for mediaType in [MediaType.movie, MediaType.series] {
            guard !isCancellationRequested else {
                return OperationResult(
                    count: createdOrUpdated,
                    errors: errors,
                    localRefreshTargets: localRefreshTargets
                )
            }
            let items: [TraktRatingItem]
            switch await collectRemotePages(
                resource: "Remote Trakt \(mediaType.rawValue) ratings pull",
                fetchPage: { [self] page in
                    try await self.traktService.getRatings(type: mediaType, page: page)
                }
            ) {
            case .success(let fetchedItems):
                items = fetchedItems
            case .cancelled:
                return OperationResult(
                    count: createdOrUpdated,
                    errors: errors,
                    localRefreshTargets: localRefreshTargets
                )
            case .failure(let error):
                errors.append(error)
                continue
            }

            for item in items {
                guard !isCancellationRequested else {
                    return OperationResult(
                        count: createdOrUpdated,
                        errors: errors,
                        localRefreshTargets: localRefreshTargets
                    )
                }
                guard let remoteMediaId = extractRatingMediaId(from: item) else { continue }
                do {
                    let mediaId = try await canonicalLocalMediaId(for: remoteMediaId)
                    let existing = try await database.fetchLatestTasteRating(mediaId: mediaId)
                    let localMediaId = existing?.mediaId ?? mediaId
                    let remoteRating = Double(item.rating)
                    let remoteRatedAt = parseHistoryDate(item.ratedAt)
                    // Compare ratings in normalized [0,1] space using the existing event's own
                    // scale, so e.g. a local 80/100 equals Trakt 8 and isn't mistaken for a change
                    // (which would write a spurious shadow .oneToTen rating that shadows the real
                    // one). The write below intentionally still records the canonical remote value.
                    let remoteNormalized = FeedbackScaleMode.oneToTen.normalizedValue(remoteRating)
                    let localScale = (existing?.feedbackScale ?? .oneToTen).canonicalMode
                    let localNormalized = existing?.feedbackValue.map { localScale.normalizedValue($0) }
                    let ratingsDiffer = localNormalized.map { abs($0 - remoteNormalized) > (0.5 / 9.0) } ?? true
                    let shouldWriteEvent: Bool

                    if existing == nil {
                        shouldWriteEvent = true
                    } else if ratingsDiffer {
                        shouldWriteEvent = true
                    } else if let existing,
                              let remoteRatedAt,
                              remoteRatedAt > existing.createdAt {
                        shouldWriteEvent = true
                    } else {
                        shouldWriteEvent = false
                    }

                    guard shouldWriteEvent else { continue }

                    let event = TasteEvent(
                        userId: "default",
                        mediaId: localMediaId,
                        eventType: .rated,
                        signalStrength: 1.0,
                        feedbackScale: .oneToTen,
                        feedbackValue: remoteRating,
                        source: .automatic,
                        metadata: ["trakt_synced": "true"],
                        createdAt: remoteRatedAt ?? Date()
                    )
                    try await database.saveTasteEvent(event)
                    createdOrUpdated += 1
                    localRefreshTargets.insert(.tasteProfile)
                } catch {
                    if isCancellationError(error) {
                        return OperationResult(
                            count: createdOrUpdated,
                            errors: errors,
                            localRefreshTargets: localRefreshTargets
                        )
                    }
                    errors.append(Self.sanitizedSyncError(prefix: "Pull rating \(remoteMediaId)", error: error))
                }
            }
        }

        return OperationResult(
            count: createdOrUpdated,
            errors: errors,
            localRefreshTargets: localRefreshTargets
        )
    }

    /// Maximum number of pages to fetch during remote page collection.
    /// `nil` disables the cap; tests may inject a smaller explicit limit.
    static let defaultMaxHistoryPages: Int? = nil
    /// Backwards-compatible alias.
    static var maxHistoryPages: Int? { defaultMaxHistoryPages }
    private let maxPages: Int?

    private func pullHistory() async -> OperationResult {
        var created = 0
        var errors: [String] = []
        var localRefreshTargets: SyncResult.LocalRefreshTargets = []

        for mediaType in [MediaType.movie, MediaType.series] {
            guard !isCancellationRequested else {
                return OperationResult(
                    count: created,
                    errors: errors,
                    localRefreshTargets: localRefreshTargets
                )
            }
            do {
                var page = 1
                var keepPaging = true

                while keepPaging {
                    guard !isCancellationRequested else {
                        return OperationResult(
                            count: created,
                            errors: errors,
                            localRefreshTargets: localRefreshTargets
                        )
                    }
                    if let maxPages, page > maxPages {
                        errors.append(
                            "Pull history (\(mediaType.rawValue)) exceeded the \(maxPages)-page cap. Remote state is incomplete."
                        )
                        break
                    }
                    let items = try await traktService.getHistory(type: mediaType, page: page)
                    guard !isCancellationRequested else {
                        return OperationResult(
                            count: created,
                            errors: errors,
                            localRefreshTargets: localRefreshTargets
                        )
                    }

                    for item in items {
                        guard !isCancellationRequested else {
                            return OperationResult(
                                count: created,
                                errors: errors,
                                localRefreshTargets: localRefreshTargets
                            )
                        }
                        guard let identifiers = extractHistoryIdentifiers(from: item) else { continue }
                        let episodeId = identifiers.episodeId

                        do {
                            let mediaId = try await canonicalLocalMediaId(for: identifiers.mediaId)
                            // Write to WatchHistory table (what the app actually displays)
                            let watchedAt = parseHistoryDate(item.watchedAt) ?? Date()
                            let existingWatch = try await hasCompletedWatchHistoryEntry(
                                mediaId: mediaId,
                                episodeId: episodeId,
                                episodeAliases: identifiers.episodeAliases,
                                watchedAt: watchedAt
                            )
                            if !existingWatch {
                                let title = extractHistoryTitle(from: item)

                                let watchHistory = WatchHistory(
                                    id: UUID().uuidString,
                                    mediaId: mediaId,
                                    episodeId: episodeId,
                                    title: title,
                                    progress: 0,
                                    duration: 0,
                                    quality: nil,
                                    debridService: nil,
                                    streamURL: nil,
                                    watchedAt: watchedAt,
                                    isCompleted: true
                                )
                                try await database.saveWatchHistory(watchHistory)
                                created += 1
                                localRefreshTargets.insert(.library)
                            }

                            // Also keep UserLibraryEntry for backwards compatibility
                            let libraryExists = try await database.isInLibrary(
                                mediaId: mediaId,
                                listType: .history
                            )
                            if !libraryExists {
                                let entry = UserLibraryEntry(
                                    id: UUID().uuidString,
                                    mediaId: mediaId,
                                    folderId: LibraryFolder.systemFolderID(for: .history),
                                    listType: .history,
                                    addedAt: Date()
                                )
                                try await database.addToLibrary(entry)
                                localRefreshTargets.insert(.library)
                            }

                            let traktItem = TraktItem(
                                rank: nil,
                                listedAt: nil,
                                movie: item.movie,
                                show: item.show
                            )
                            if (try? await ensureMediaItem(from: traktItem, mediaId: mediaId)) == true {
                                localRefreshTargets.insert(.library)
                            }
                        } catch {
                            if isCancellationError(error) {
                                return OperationResult(
                                    count: created,
                                    errors: errors,
                                    localRefreshTargets: localRefreshTargets
                                )
                            }
                            errors.append(Self.sanitizedSyncError(prefix: "Pull history entry \(identifiers.mediaId)", error: error))
                        }
                    }

                    // Stop paging if this page had fewer than 50 items (last page)
                    keepPaging = items.count >= 50
                    page += 1
                }
            } catch {
                if isCancellationError(error) {
                    return OperationResult(
                        count: created,
                        errors: errors,
                        localRefreshTargets: localRefreshTargets
                    )
                }
                errors.append(Self.sanitizedSyncError(prefix: "Pull history (\(mediaType.rawValue))", error: error))
            }
        }

        return OperationResult(
            count: created,
            errors: errors,
            localRefreshTargets: localRefreshTargets
        )
    }

    // MARK: - Push Operations

    private func pushWatchlist() async -> OperationResult {
        var pushed = 0
        var errors: [String] = []

        do {
            guard !isCancellationRequested else {
                return OperationResult(count: pushed, errors: errors, localRefreshTargets: [])
            }
            let localEntries = try await database.fetchLibraryEntries(listType: .watchlist)
            let remoteSyncIds: Set<String>
            switch await fetchRemoteWatchlistSyncIds() {
            case .success(let ids):
                remoteSyncIds = ids
            case .cancelled:
                return OperationResult(count: pushed, errors: errors, localRefreshTargets: [])
            case .failure(let error):
                errors.append(error)
                return OperationResult(count: 0, errors: errors, localRefreshTargets: [])
            }

            for entry in localEntries {
                guard !isCancellationRequested else {
                    return OperationResult(count: pushed, errors: errors, localRefreshTargets: [])
                }
                guard let syncId = await localTraktSyncID(for: entry.mediaId) else { continue }
                guard !remoteSyncIds.contains(syncId) else { continue }

                do {
                    let mediaType = await resolveMediaType(for: entry.mediaId)
                    try await traktService.addToWatchlist(imdbId: syncId, type: mediaType)
                    pushed += 1
                } catch {
                    if isCancellationError(error) {
                        return OperationResult(count: pushed, errors: errors, localRefreshTargets: [])
                    }
                    errors.append(Self.sanitizedSyncError(prefix: "Push watchlist \(syncId)", error: error))
                }
            }
        } catch {
            if isCancellationError(error) {
                return OperationResult(count: pushed, errors: errors, localRefreshTargets: [])
            }
            errors.append(Self.sanitizedSyncError(prefix: "Push watchlist fetch", error: error))
        }

        return OperationResult(
            count: pushed,
            errors: errors,
            localRefreshTargets: []
        )
    }

    private func pushRatings() async -> OperationResult {
        var pushed = 0
        var errors: [String] = []

        do {
            guard !isCancellationRequested else {
                return OperationResult(count: pushed, errors: errors, localRefreshTargets: [])
            }
            let remoteRatingsBySyncId: [String: TraktRatingItem]
            switch await fetchRemoteRatingsBySyncId() {
            case .success(let ratings):
                remoteRatingsBySyncId = ratings
            case .cancelled:
                return OperationResult(count: pushed, errors: errors, localRefreshTargets: [])
            case .failure(let error):
                errors.append(error)
                return OperationResult(count: 0, errors: errors, localRefreshTargets: [])
            }

            // Deduplicate across all local pages: keep the newest event per mediaId.
            var latestEventsByMediaId: [String: TasteEvent] = [:]
            let pageSize = 500
            var offset = 0

            while true {
                guard !isCancellationRequested else {
                    return OperationResult(count: pushed, errors: errors, localRefreshTargets: [])
                }
                let page = try await database.fetchTasteEvents(
                    eventType: .rated,
                    limit: pageSize,
                    offset: offset
                )
                if page.isEmpty { break }

                for event in page {
                    guard let mediaId = event.mediaId,
                          let syncId = await localTraktSyncID(for: mediaId) else { continue }
                    if latestEventsByMediaId[syncId] == nil {
                        latestEventsByMediaId[syncId] = event
                    }
                }

                if page.count < pageSize { break }
                offset += page.count
            }

            for (syncId, event) in latestEventsByMediaId {
                guard !isCancellationRequested else {
                    return OperationResult(count: pushed, errors: errors, localRefreshTargets: [])
                }
                guard let clampedRating = traktRating(from: event) else { continue }

                if let remoteRating = remoteRatingsBySyncId[syncId],
                   remoteRating.rating == clampedRating {
                    continue
                }

                do {
                    let mediaType = await resolveMediaType(for: event.mediaId ?? syncId)
                    try await traktService.addRating(
                        imdbId: syncId,
                        rating: clampedRating,
                        type: mediaType
                    )
                    pushed += 1
                } catch {
                    if isCancellationError(error) {
                        return OperationResult(count: pushed, errors: errors, localRefreshTargets: [])
                    }
                    errors.append(Self.sanitizedSyncError(prefix: "Push rating \(syncId)", error: error))
                }
            }
        } catch {
            if isCancellationError(error) {
                return OperationResult(count: pushed, errors: errors, localRefreshTargets: [])
            }
            errors.append(Self.sanitizedSyncError(prefix: "Push ratings fetch", error: error))
        }

        return OperationResult(
            count: pushed,
            errors: errors,
            localRefreshTargets: []
        )
    }

    private func pushHistory() async -> OperationResult {
        var pushed = 0
        var errors: [String] = []

        do {
            guard !isCancellationRequested else {
                return OperationResult(count: pushed, errors: errors, localRefreshTargets: [])
            }
            let remoteHistoryKeys: Set<String>
            switch await fetchRemoteHistoryKeys() {
            case .success(let keys):
                remoteHistoryKeys = keys
            case .cancelled:
                return OperationResult(count: pushed, errors: errors, localRefreshTargets: [])
            case .failure(let error):
                errors.append(error)
                return OperationResult(count: 0, errors: errors, localRefreshTargets: [])
            }
            let pageSize = 1000
            var offset = 0

            while true {
                guard !isCancellationRequested else {
                    return OperationResult(count: pushed, errors: errors, localRefreshTargets: [])
                }
                let localEntries = try await database.fetchCompletedWatchHistory(
                    limit: pageSize,
                    offset: offset
                )
                if localEntries.isEmpty { break }

                for entry in localEntries {
                    guard !isCancellationRequested else {
                        return OperationResult(count: pushed, errors: errors, localRefreshTargets: [])
                    }
                    guard let syncId = await localTraktSyncID(for: entry.mediaId) else { continue }
                    guard TraktEpisodeIdentifierPolicy.canSyncEpisodeID(entry.episodeId) else { continue }

                    let syncKeys = historySyncKeys(
                        mediaId: syncId,
                        episodeId: entry.episodeId,
                        watchedAt: entry.watchedAt
                    )
                    guard remoteHistoryKeys.isDisjoint(with: syncKeys) else { continue }

                    do {
                        let mediaType: MediaType
                        if entry.episodeId != nil {
                            mediaType = .series
                        } else {
                            mediaType = await resolveMediaType(for: entry.mediaId)
                        }

                        try await traktService.addToHistory(
                            imdbId: syncId,
                            type: mediaType,
                            episodeId: entry.episodeId,
                            watchedAt: entry.watchedAt
                        )
                        pushed += 1
                    } catch {
                        if isCancellationError(error) {
                            return OperationResult(count: pushed, errors: errors, localRefreshTargets: [])
                        }
                        errors.append(Self.sanitizedSyncError(prefix: "Push history \(syncId)", error: error))
                    }
                }

                if localEntries.count < pageSize { break }
                offset += localEntries.count
            }
        } catch {
            if isCancellationError(error) {
                return OperationResult(count: pushed, errors: errors, localRefreshTargets: [])
            }
            errors.append(Self.sanitizedSyncError(prefix: "Push history fetch", error: error))
        }

        return OperationResult(
            count: pushed,
            errors: errors,
            localRefreshTargets: []
        )
    }

    // MARK: - Custom List / Folder Sync

    private struct FolderSyncResult {
        var pulled: Int
        var pushed: Int
        var errors: [String]
        var localRefreshTargets: SyncResult.LocalRefreshTargets

        var shouldAdvanceLastSyncDate: Bool {
            pulled > 0 || pushed > 0 || errors.isEmpty
        }
    }

    /// Bi-directional sync between local Library folders and Trakt custom lists.
    ///
    /// **Pull:** Trakt lists without a local mapping create a new local folder + mapping.
    ///           Items in each Trakt list are added to the corresponding local folder.
    /// **Push:** Local custom folders without a Trakt mapping create a new Trakt list + mapping.
    ///           Items in each local folder are pushed to the corresponding Trakt list.
    private func syncCustomLists() async -> FolderSyncResult {
        var pulled = 0
        var pushed = 0
        var errors: [String] = []
        var localRefreshTargets: SyncResult.LocalRefreshTargets = []

        // --- Pull: Trakt lists → local folders ---

        do {
            let remoteLists = try await traktService.getCustomLists()
            let existingMappings = try await database.fetchAllTraktListMappings()
            let mappedTraktIds = Set(existingMappings.map(\.traktListId))

            for list in remoteLists {
                guard !isCancellationRequested else {
                    return FolderSyncResult(
                        pulled: pulled,
                        pushed: pushed,
                        errors: errors,
                        localRefreshTargets: localRefreshTargets
                    )
                }
                let traktId = list.ids.trakt

                if mappedTraktIds.contains(traktId) {
                    // Already mapped — sync items into the existing folder
                    guard let mapping = existingMappings.first(where: { $0.traktListId == traktId }) else { continue }
                    do {
                        let pullResult = try await pullListItems(
                            traktListId: traktId,
                            localFolderId: mapping.localFolderId,
                            listType: mapping.listType
                        )
                        pulled += pullResult.count
                        if pullResult.didMutateLibrary {
                            localRefreshTargets.insert(.library)
                        }
                    } catch is CancellationError {
                        return FolderSyncResult(
                            pulled: pulled,
                            pushed: pushed,
                            errors: errors,
                            localRefreshTargets: localRefreshTargets
                        )
                    } catch {
                        errors.append(Self.sanitizedSyncError(prefix: "Pull list items \(list.name)", error: error))
                    }
                } else {
                    // New Trakt list — create local folder + mapping
                    do {
                        var folder = try await database.createLibraryFolder(
                            name: list.name,
                            listType: .watchlist
                        )
                        // createLibraryFolder dedupes by name, so a Trakt list whose name matches a
                        // folder already mapped to a DIFFERENT Trakt list would make
                        // saveTraktListMapping violate the UNIQUE(localFolderId) index and throw —
                        // silently dropping this list from sync. Disambiguate with a suffixed name
                        // so one folder maps to exactly one Trakt list.
                        var disambiguationSuffix = 2
                        while let collidingMapping = try await database.fetchTraktListMapping(localFolderId: folder.id),
                              collidingMapping.traktListId != traktId {
                            folder = try await database.createLibraryFolder(
                                name: "\(list.name) (\(disambiguationSuffix))",
                                listType: .watchlist
                            )
                            disambiguationSuffix += 1
                        }
                        localRefreshTargets.insert(.library)
                        let mapping = TraktListMapping(
                            traktListId: traktId,
                            traktListSlug: list.ids.slug,
                            localFolderId: folder.id,
                            listType: .watchlist
                        )
                        try await database.saveTraktListMapping(mapping)

                        let pullResult = try await pullListItems(
                            traktListId: traktId,
                            localFolderId: folder.id,
                            listType: .watchlist
                        )
                        pulled += pullResult.count
                        if pullResult.didMutateLibrary {
                            localRefreshTargets.insert(.library)
                        }
                    } catch is CancellationError {
                        return FolderSyncResult(
                            pulled: pulled,
                            pushed: pushed,
                            errors: errors,
                            localRefreshTargets: localRefreshTargets
                        )
                    } catch {
                        errors.append(Self.sanitizedSyncError(prefix: "Create folder for Trakt list \(list.name)", error: error))
                    }
                }
            }
        } catch {
            if isCancellationError(error) {
                return FolderSyncResult(
                    pulled: pulled,
                    pushed: pushed,
                    errors: errors,
                    localRefreshTargets: localRefreshTargets
                )
            }
            errors.append(Self.sanitizedSyncError(prefix: "Fetch Trakt custom lists", error: error))
        }

        // --- Push: local folders → Trakt lists ---

        do {
            let allFolders = try await database.fetchAllLibraryFolders(listType: .watchlist)
            let customFolders = allFolders.filter { !$0.isSystem }
            let existingMappings = try await database.fetchAllTraktListMappings()
            let mappedFolderIds = Set(existingMappings.map(\.localFolderId))

            for folder in customFolders {
                guard !isCancellationRequested else {
                    return FolderSyncResult(
                        pulled: pulled,
                        pushed: pushed,
                        errors: errors,
                        localRefreshTargets: localRefreshTargets
                    )
                }
                if mappedFolderIds.contains(folder.id) {
                    // Already mapped — push local items not yet on the Trakt list
                    guard let mapping = existingMappings.first(where: { $0.localFolderId == folder.id }) else { continue }
                    do {
                        let itemsPushed = try await pushFolderItems(
                            localFolderId: folder.id,
                            traktListId: mapping.traktListId,
                            listType: mapping.listType
                        )
                        pushed += itemsPushed
                    } catch is CancellationError {
                        return FolderSyncResult(
                            pulled: pulled,
                            pushed: pushed,
                            errors: errors,
                            localRefreshTargets: localRefreshTargets
                        )
                    } catch {
                        errors.append(Self.sanitizedSyncError(prefix: "Push folder items \(folder.name)", error: error))
                    }
                } else {
                    // New local folder — create Trakt list + mapping
                    do {
                        let traktList = try await traktService.createCustomList(name: folder.name)
                        let mapping = TraktListMapping(
                            traktListId: traktList.ids.trakt,
                            traktListSlug: traktList.ids.slug,
                            localFolderId: folder.id,
                            listType: .watchlist
                        )
                        try await database.saveTraktListMapping(mapping)

                        let itemsPushed = try await pushFolderItems(
                            localFolderId: folder.id,
                            traktListId: traktList.ids.trakt,
                            listType: .watchlist
                        )
                        pushed += itemsPushed
                    } catch is CancellationError {
                        return FolderSyncResult(
                            pulled: pulled,
                            pushed: pushed,
                            errors: errors,
                            localRefreshTargets: localRefreshTargets
                        )
                    } catch {
                        errors.append(Self.sanitizedSyncError(prefix: "Create Trakt list for folder \(folder.name)", error: error))
                    }
                }
            }
        } catch {
            if isCancellationError(error) {
                return FolderSyncResult(
                    pulled: pulled,
                    pushed: pushed,
                    errors: errors,
                    localRefreshTargets: localRefreshTargets
                )
            }
            errors.append(Self.sanitizedSyncError(prefix: "Fetch local folders", error: error))
        }

        return FolderSyncResult(
            pulled: pulled,
            pushed: pushed,
            errors: errors,
            localRefreshTargets: localRefreshTargets
        )
    }

    /// Pulls items from a Trakt list into a local folder.
    private func pullListItems(
        traktListId: Int,
        localFolderId: String,
        listType: UserLibraryEntry.ListType
    ) async throws -> (count: Int, didMutateLibrary: Bool) {
        try Task.checkCancellation()
        let items = try await traktService.getListItems(listId: traktListId)
        var created = 0
        var removed = 0
        var didMutateLibrary = false

        var remoteIdentityKeys = Set<String>()
        var localIdentityKeys = Set<String>()
        let initialLocalEntries = try await database.fetchLibraryEntries(listType: listType, folderId: localFolderId)
        for entry in initialLocalEntries {
            localIdentityKeys.formUnion(await syncIdentities(for: entry.mediaId))
        }

        for item in items {
            try Task.checkCancellation()
            let mediaIDs = Self.mediaIDCandidates(from: item)
            guard let mediaId = mediaIDs.first else { continue }
            let remoteIdentities = await syncIdentities(for: mediaIDs)
            remoteIdentityKeys.formUnion(remoteIdentities)

            let existsInFolder = !localIdentityKeys.isDisjoint(with: remoteIdentities)
            if !existsInFolder {
                let entry = UserLibraryEntry(
                    id: "\(mediaId)-\(listType.rawValue)-\(localFolderId)",
                    mediaId: mediaId,
                    folderId: localFolderId,
                    listType: listType,
                    addedAt: Date()
                )
                try await database.addToLibrary(entry)
                localIdentityKeys.formUnion(remoteIdentities)
                created += 1
                didMutateLibrary = true
            }
            // Ensure a stub MediaItem exists so LibraryView can display it
            let traktItem = TraktItem(
                rank: nil, listedAt: nil,
                movie: item.movie, show: item.show
            )
            if (try? await ensureMediaItem(from: traktItem, mediaId: mediaId)) == true {
                didMutateLibrary = true
            }
        }

        // Delete local entries that were removed from the remote list.
        let localEntries = try await database.fetchLibraryEntries(listType: listType, folderId: localFolderId)
        for entry in localEntries {
            try Task.checkCancellation()
            let localIdentities = await syncIdentities(for: entry.mediaId)
            guard remoteIdentityKeys.isDisjoint(with: localIdentities) else { continue }
            try await database.removeFromLibrary(
                mediaId: entry.mediaId,
                listType: listType,
                folderId: localFolderId
            )
            removed += 1
            didMutateLibrary = true
        }

        return (count: created + removed, didMutateLibrary: didMutateLibrary)
    }

    /// Pushes items from a local folder to a Trakt list.
    private func pushFolderItems(
        localFolderId: String,
        traktListId: Int,
        listType: UserLibraryEntry.ListType
    ) async throws -> Int {
        try Task.checkCancellation()
        let entries = try await database.fetchLibraryEntries(
            listType: listType,
            folderId: localFolderId
        )

        // Get existing items on the Trakt list for dedup and removals.
        let remoteItems = try await traktService.getListItems(listId: traktListId)
        var remoteBySyncId: [String: MediaType] = [:]
        var remoteIdentitiesBySyncId: [String: Set<String>] = [:]
        var remoteIdentityKeys = Set<String>()
        for item in remoteItems {
            let movieCandidates = Self.mediaIDCandidates(from: item.movie?.ids, type: .movie)
            let showCandidates = Self.mediaIDCandidates(from: item.show?.ids, type: .series)
            let mediaIDs = movieCandidates + showCandidates
            let identities = await syncIdentities(for: mediaIDs)
            remoteIdentityKeys.formUnion(identities)

            if let movieSyncId = Self.preferredSyncID(from: movieCandidates) {
                remoteBySyncId[movieSyncId] = .movie
                remoteIdentitiesBySyncId[movieSyncId, default: []].formUnion(identities)
            }
            if let showSyncId = Self.preferredSyncID(from: showCandidates) {
                remoteBySyncId[showSyncId] = .series
                remoteIdentitiesBySyncId[showSyncId, default: []].formUnion(identities)
            }
        }

        var localIdentitiesBySyncId: [String: Set<String>] = [:]
        var localMediaTypeBySyncId: [String: MediaType] = [:]
        var localIdentityKeys = Set<String>()
        for entry in entries {
            try Task.checkCancellation()
            let identities = await syncIdentities(for: entry.mediaId)
            localIdentityKeys.formUnion(identities)
            if let syncID = await localTraktSyncID(for: entry.mediaId) {
                localIdentitiesBySyncId[syncID, default: []].formUnion(identities)
                if localMediaTypeBySyncId[syncID] == nil {
                    localMediaTypeBySyncId[syncID] = await resolveMediaType(for: entry.mediaId)
                }
            }
        }
        let remoteSyncIds = Set(remoteBySyncId.keys)

        // Collect additions.
        var toAdd: [(id: String, type: MediaType)] = []
        for (syncId, localIdentities) in localIdentitiesBySyncId {
            try Task.checkCancellation()
            guard !remoteSyncIds.contains(syncId),
                  remoteIdentityKeys.isDisjoint(with: localIdentities) else {
                continue
            }
            let mediaType: MediaType
            if let hintedType = localMediaTypeBySyncId[syncId] {
                mediaType = hintedType
            } else {
                mediaType = await resolveMediaType(for: syncId)
            }
            toAdd.append((id: syncId, type: mediaType))
        }

        if !toAdd.isEmpty {
            try Task.checkCancellation()
            try await traktService.addToCustomList(listId: traktListId, imdbIds: toAdd)
        }

        // Collect removals.
        let toRemove = remoteSyncIds.compactMap { syncId -> (id: String, type: MediaType)? in
            guard let mediaType = remoteBySyncId[syncId] else { return nil }
            let remoteIdentities = remoteIdentitiesBySyncId[syncId] ?? [syncId]
            guard localIdentityKeys.isDisjoint(with: remoteIdentities) else { return nil }
            return (id: syncId, type: mediaType)
        }
        if !toRemove.isEmpty {
            try Task.checkCancellation()
            try await traktService.removeFromCustomList(listId: traktListId, imdbIds: toRemove)
        }

        return toAdd.count + toRemove.count
    }

    // MARK: - Helpers

    /// Extracts a local media ID from a TraktItem, preferring typed OMDb/IMDb IDs and falling back to TMDb.
    private func extractMediaId(from item: TraktItem) -> String? {
        if let imdb = IMDbIdentifierPolicy.normalizedID(from: item.movie?.ids.imdb) {
            return Self.omdbMediaID(imdb: imdb, type: .movie)
        }
        if let imdb = IMDbIdentifierPolicy.normalizedID(from: item.show?.ids.imdb) {
            return Self.omdbMediaID(imdb: imdb, type: .series)
        }
        if let tmdb = item.movie?.ids.tmdb { return Self.tmdbMediaID(tmdb: tmdb, type: .movie) }
        if let tmdb = item.show?.ids.tmdb { return Self.tmdbMediaID(tmdb: tmdb, type: .series) }
        return nil
    }

    private func extractRatingMediaId(from item: TraktRatingItem) -> String? {
        if let imdb = IMDbIdentifierPolicy.normalizedID(from: item.movie?.ids.imdb) {
            return Self.omdbMediaID(imdb: imdb, type: .movie)
        }
        if let imdb = IMDbIdentifierPolicy.normalizedID(from: item.show?.ids.imdb) {
            return Self.omdbMediaID(imdb: imdb, type: .series)
        }
        if let tmdb = item.movie?.ids.tmdb { return Self.tmdbMediaID(tmdb: tmdb, type: .movie) }
        if let tmdb = item.show?.ids.tmdb { return Self.tmdbMediaID(tmdb: tmdb, type: .series) }
        return nil
    }

    private struct HistoryIdentifiers {
        let mediaId: String
        let episodeId: String?
        let episodeAliases: Set<String>
    }

    private enum RemotePageCollection<T> {
        case success(T)
        case cancelled
        case failure(String)
    }

    private func collectRemotePages<T>(
        resource: String,
        fetchPage: @escaping (Int) async throws -> [T]
    ) async -> RemotePageCollection<[T]> {
        var itemsByPage: [T] = []
        var page = 1

        while true {
            if isCancellationRequested {
                return .cancelled
            }
            do {
                let pageItems = try await fetchPage(page)
                if isCancellationRequested {
                    return .cancelled
                }
                itemsByPage.append(contentsOf: pageItems)

                let hasMorePages = pageItems.count >= 50
                guard hasMorePages else {
                    return .success(itemsByPage)
                }

                if let maxPages, page == maxPages {
                    return .failure(
                        "\(resource) exceeded the \(maxPages)-page deduplication cap. Remote state is incomplete, so the push was skipped."
                    )
                }

                page += 1
            } catch {
                if isCancellationError(error) {
                    return .cancelled
                }
                return .failure(Self.sanitizedSyncError(
                    prefix: "\(resource) page \(page) failed during deduplication",
                    error: error
                ))
            }
        }

        return .success(itemsByPage)
    }

    static func sanitizedSyncError(prefix: String, error: Error) -> String {
        "\(prefix): \(IndexerLogSanitizer.redactedErrorMessage(error))"
    }

    private func extractHistoryIdentifiers(from item: TraktHistoryItem) -> HistoryIdentifiers? {
        if let imdb = IMDbIdentifierPolicy.normalizedID(from: item.movie?.ids.imdb) {
            return HistoryIdentifiers(
                mediaId: Self.omdbMediaID(imdb: imdb, type: .movie),
                episodeId: nil,
                episodeAliases: []
            )
        }
        if let tmdb = item.movie?.ids.tmdb {
            return HistoryIdentifiers(
                mediaId: Self.tmdbMediaID(tmdb: tmdb, type: .movie),
                episodeId: nil,
                episodeAliases: []
            )
        }

        let mediaId: String?
        if let imdb = IMDbIdentifierPolicy.normalizedID(from: item.show?.ids.imdb) {
            mediaId = Self.omdbMediaID(imdb: imdb, type: .series)
        } else if let tmdb = item.show?.ids.tmdb {
            mediaId = Self.tmdbMediaID(tmdb: tmdb, type: .series)
        } else {
            mediaId = nil
        }

        guard let mediaId else { return nil }

        var episodeAliases = Set<String>()
        let seasonEpisodeID: String?
        if let season = item.episode?.season,
           let number = item.episode?.number {
            let resolvedEpisodeID = String(format: "s%02de%02d", season, number)
            seasonEpisodeID = resolvedEpisodeID
            episodeAliases.insert(resolvedEpisodeID)
        } else {
            seasonEpisodeID = nil
        }

        let episodeIMDbID = IMDbIdentifierPolicy.episodeScopedID(in: item.episode?.ids?.imdb)
        if let episodeIMDbID {
            episodeAliases.insert(episodeIMDbID)
        }

        let episodeTMDBID = item.episode?.ids?.tmdb.map { "tmdb-episode-\($0)" }
        if let episodeTMDBID {
            episodeAliases.insert(episodeTMDBID)
        }

        let episodeId: String?
        if let seasonEpisodeID {
            episodeId = seasonEpisodeID
        } else if let episodeIMDbID {
            episodeId = episodeIMDbID
        } else if let episodeTMDBID {
            episodeId = episodeTMDBID
        } else {
            episodeId = nil
        }

        return HistoryIdentifiers(
            mediaId: mediaId,
            episodeId: episodeId,
            episodeAliases: episodeAliases
        )
    }

    private static func omdbMediaID(imdb: String, type: MediaType) -> String {
        switch type {
        case .movie:
            return "movie-omdb-\(imdb)"
        case .series:
            return "series-omdb-\(imdb)"
        }
    }

    private static func tmdbMediaID(tmdb: Int, type: MediaType) -> String {
        "\(type.rawValue)-tmdb-\(tmdb)"
    }

    private func canonicalLocalMediaId(for mediaId: String) async throws -> String {
        try await database.fetchMediaItemResolvingAliases(id: mediaId)?.id ?? mediaId
    }

    /// Fetches all usable IMDb/TMDb identities in the remote Trakt watchlist for deduplication during push.
    private func fetchRemoteWatchlistSyncIds() async -> RemotePageCollection<Set<String>> {
        var ids = Set<String>()
        for mediaType in [MediaType.movie, MediaType.series] {
            if isCancellationRequested {
                return .cancelled
            }
            let remoteItems: [TraktItem]
            switch await collectRemotePages(
                resource: "Remote Trakt \(mediaType.rawValue) watchlist",
                fetchPage: { [self] page in
                    try await self.traktService.getWatchlist(type: mediaType, page: page)
                }
            ) {
            case .success(let items):
                remoteItems = items
            case .cancelled:
                return .cancelled
            case .failure(let error):
                return .failure(error)
            }

            for item in remoteItems {
                if isCancellationRequested {
                    return .cancelled
                }
                let candidates = Self.mediaIDCandidates(
                    from: item.movie?.ids ?? item.show?.ids,
                    type: mediaType
                )
                ids.formUnion(await syncIdentities(for: candidates))
            }
        }
        return .success(ids)
    }

    /// Fetches latest Trakt ratings keyed by every usable IMDb/TMDb identity Trakt returns.
    private func fetchRemoteRatingsBySyncId() async -> RemotePageCollection<[String: TraktRatingItem]> {
        var ratings: [String: TraktRatingItem] = [:]

        for mediaType in [MediaType.movie, MediaType.series] {
            if isCancellationRequested {
                return .cancelled
            }
            let remoteItems: [TraktRatingItem]
            switch await collectRemotePages(
                resource: "Remote Trakt \(mediaType.rawValue) ratings",
                fetchPage: { [self] page in
                    try await self.traktService.getRatings(type: mediaType, page: page)
                }
            ) {
            case .success(let items):
                remoteItems = items
            case .cancelled:
                return .cancelled
            case .failure(let error):
                return .failure(error)
            }

            for item in remoteItems {
                if isCancellationRequested {
                    return .cancelled
                }
                let identities = await syncIdentities(for: Self.ratingMediaIDCandidates(from: item))
                for identity in identities {
                    if ratings[identity] == nil {
                        ratings[identity] = item
                    }
                }
            }
        }

        return .success(ratings)
    }

    /// Fetches remote Trakt history keys for deduplication during push.
    /// Respects the same optional page limit as pullHistory when one is injected.
    private func fetchRemoteHistoryKeys() async -> RemotePageCollection<Set<String>> {
        var keys = Set<String>()
        for mediaType in [MediaType.movie, MediaType.series] {
            if isCancellationRequested {
                return .cancelled
            }
            let remoteItems: [TraktHistoryItem]
            switch await collectRemotePages(
                resource: "Remote Trakt \(mediaType.rawValue) history",
                fetchPage: { [self] page in
                    try await self.traktService.getHistory(type: mediaType, page: page)
                }
            ) {
            case .success(let items):
                remoteItems = items
            case .cancelled:
                return .cancelled
            case .failure(let error):
                return .failure(error)
            }

            for item in remoteItems {
                if isCancellationRequested {
                    return .cancelled
                }
                guard let identifiers = extractHistoryIdentifiers(from: item) else { continue }
                let watchedAt = parseHistoryDate(item.watchedAt)
                let mediaIdentities = await syncIdentities(for: identifiers.mediaId)
                for identity in mediaIdentities {
                    keys.formUnion(
                        historySyncKeys(
                            mediaId: identity,
                            episodeAliases: identifiers.episodeAliases,
                            watchedAt: watchedAt
                        )
                    )
                }
            }
        }
        return .success(keys)
    }

    /// Extracts a display title from a Trakt history item.
    private func extractHistoryTitle(from item: TraktHistoryItem) -> String {
        item.movie?.title ?? item.show?.title ?? "Unknown"
    }

    /// Parses an ISO 8601 date string from Trakt into a `Date`.
    private func parseHistoryDate(_ dateString: String?) -> Date? {
        guard let dateString else { return nil }
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: dateString) { return date }
        // Fallback without fractional seconds
        formatter.formatOptions = [.withInternetDateTime]
        if let date = formatter.date(from: dateString) { return date }
        // Fallback: date-only
        formatter.formatOptions = [.withFullDate]
        return formatter.date(from: dateString)
    }

    /// Creates a stub MediaItem from Trakt data if one doesn't already exist locally.
    /// This ensures LibraryView can display the entry even before full metadata is fetched.
    private func ensureMediaItem(from item: TraktItem, mediaId: String) async throws -> Bool {
        if (try? await database.fetchMediaItemResolvingAliases(id: mediaId)) != nil { return false }
        let title = item.movie?.title ?? item.show?.title ?? "Unknown"
        let year = item.movie?.year ?? item.show?.year
        let type: MediaType = item.show != nil ? .series : .movie
        let tmdbId = item.movie?.ids.tmdb ?? item.show?.ids.tmdb
        let stub = MediaItem(
            id: mediaId,
            type: type,
            title: title,
            year: year,
            posterPath: nil,
            backdropPath: nil,
            overview: nil,
            genres: [],
            imdbRating: nil,
            runtime: nil,
            status: nil,
            tmdbId: tmdbId,
            lastFetched: nil
        )
        try await database.saveMediaItem(stub)
        return true
    }

    private func hasCompletedWatchHistoryEntry(
        mediaId: String,
        episodeId: String?,
        episodeAliases: Set<String>,
        watchedAt: Date
    ) async throws -> Bool {
        if try await database.hasCompletedWatchHistoryEntry(
            mediaId: mediaId,
            episodeId: episodeId,
            watchedAt: watchedAt
        ) {
            return true
        }

        guard !episodeAliases.isEmpty else { return false }
        let candidates = try await database.fetchCompletedWatchHistory(
            mediaId: mediaId,
            watchedAt: watchedAt
        )
        return candidates.contains { candidate in
            !Self.historyEpisodeAliases(from: candidate.episodeId).isDisjoint(with: episodeAliases)
        }
    }

    private func historySyncKey(mediaId: String, episodeId: String?, watchedAt: Date? = nil) -> String {
        historySyncKeys(mediaId: mediaId, episodeId: episodeId, watchedAt: watchedAt)
            .sorted()
            .first ?? "\(mediaId)#movie#unknown"
    }

    private func historySyncKeys(
        mediaId: String,
        episodeId: String?,
        watchedAt: Date? = nil
    ) -> Set<String> {
        historySyncKeys(
            mediaId: mediaId,
            episodeAliases: Self.historyEpisodeAliases(from: episodeId),
            watchedAt: watchedAt
        )
    }

    private func historySyncKeys(
        mediaId: String,
        episodeAliases: Set<String>,
        watchedAt: Date? = nil
    ) -> Set<String> {
        let timestampComponent = watchedAt.map { String(Int($0.timeIntervalSince1970.rounded())) } ?? "unknown"
        if episodeAliases.isEmpty {
            return ["\(mediaId)#movie#\(timestampComponent)"]
        }
        return Set(episodeAliases.map { "\(mediaId)#\($0)#\(timestampComponent)" })
    }

    private static func historyEpisodeAliases(from episodeId: String?) -> Set<String> {
        guard let trimmed = episodeId?.trimmingCharacters(in: .whitespacesAndNewlines),
              !trimmed.isEmpty else {
            return []
        }

        var aliases = Set<String>()
        if let imdbID = IMDbIdentifierPolicy.episodeScopedID(in: trimmed) {
            aliases.insert(imdbID)
        }
        if let context = TraktEpisodeIdentifierPolicy.seasonEpisode(from: trimmed) {
            aliases.insert(String(format: "s%02de%02d", context.season, context.episode))
        }
        if aliases.isEmpty {
            aliases.insert(trimmed.lowercased())
        }
        return aliases
    }

    private func traktRating(from event: TasteEvent) -> Int? {
        guard let feedbackValue = event.feedbackValue else { return nil }
        let sourceScale = (event.feedbackScale ?? .oneToTen).canonicalMode
        let normalized = sourceScale.normalizedValue(feedbackValue)
        let traktValue = FeedbackScaleMode.oneToTen.value(fromNormalized: normalized)
        return Int(FeedbackScaleMode.oneToTen.clamp(traktValue).rounded())
    }

    /// Resolves the media type for a given mediaId.
    ///
    /// Priority:
    /// 1) Cached MediaItem type
    /// 2) Existing episode watch-state evidence (series)
    /// 3) Conservative fallback to movie (legacy behavior)
    private func resolveMediaType(for mediaId: String) async -> MediaType {
        if let item = try? await database.fetchMediaItemResolvingAliases(id: mediaId) {
            return item.type
        }

        if let hintedType = Self.mediaTypeHint(from: mediaId) {
            return hintedType
        }

        if let episodeStates = try? await database.fetchEpisodeWatchStates(mediaId: mediaId),
           !episodeStates.isEmpty {
            return .series
        }

        return .movie
    }

    private static func mediaTypeHint(from mediaId: String) -> MediaType? {
        let normalized = mediaId.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if normalized.hasPrefix("series-") {
            return .series
        }
        if normalized.hasPrefix("movie-") {
            return .movie
        }
        return nil
    }

    private var isCancellationRequested: Bool {
        Task.isCancelled
    }

    private func isCancellationError(_ error: Error) -> Bool {
        error is CancellationError || Task.isCancelled
    }
}

// MARK: - SyncResult

extension TraktSyncOrchestrator {
    struct SyncResult: Sendable, Equatable {
        struct LocalRefreshTargets: OptionSet, Sendable, Equatable {
            let rawValue: Int

            static let library = LocalRefreshTargets(rawValue: 1 << 0)
            static let tasteProfile = LocalRefreshTargets(rawValue: 1 << 1)
        }

        var watchlistPulled: Int = 0
        var watchlistPushed: Int = 0
        var ratingsPulled: Int = 0
        var ratingsPushed: Int = 0
        var historyPulled: Int = 0
        var historyPushed: Int = 0
        var foldersPulled: Int = 0
        var foldersPushed: Int = 0
        var errors: [String] = []
        var localRefreshTargets: LocalRefreshTargets = []

        var totalPulled: Int { watchlistPulled + ratingsPulled + historyPulled + foldersPulled }
        var totalPushed: Int { watchlistPushed + ratingsPushed + historyPushed + foldersPushed }
        var hasErrors: Bool { !errors.isEmpty }

        var summary: String {
            var parts: [String] = []
            if watchlistPulled > 0 { parts.append("\(watchlistPulled) watchlist pulled") }
            if watchlistPushed > 0 { parts.append("\(watchlistPushed) watchlist pushed") }
            if ratingsPulled > 0 { parts.append("\(ratingsPulled) ratings pulled") }
            if ratingsPushed > 0 { parts.append("\(ratingsPushed) ratings pushed") }
            if historyPulled > 0 { parts.append("\(historyPulled) history pulled") }
            if historyPushed > 0 { parts.append("\(historyPushed) history pushed") }
            if foldersPulled > 0 { parts.append("\(foldersPulled) folder items pulled") }
            if foldersPushed > 0 { parts.append("\(foldersPushed) folder items pushed") }
            if parts.isEmpty && !hasErrors { return "Everything is up to date." }
            if parts.isEmpty && hasErrors { return "Sync completed with \(errors.count) error(s)." }
            var message = parts.joined(separator: ", ") + "."
            if hasErrors { message += " \(errors.count) error(s)." }
            return message
        }
    }

    /// Internal result type for individual pull/push operations.
    private struct OperationResult {
        let count: Int
        let errors: [String]
        let localRefreshTargets: SyncResult.LocalRefreshTargets

        var shouldAdvanceLastSyncDate: Bool {
            count > 0 || errors.isEmpty
        }
    }

    private static func localIMDbID(from mediaId: String) -> String? {
        IMDbIdentifierPolicy.appScopedID(in: mediaId)
    }

    private func localIMDbID(for mediaId: String) async -> String? {
        if let direct = Self.localIMDbID(from: mediaId) {
            return direct
        }

        let requestedTMDBID = MetadataProviderIdentifierPolicy.tmdbID(from: mediaId)
        let hintedType = Self.mediaTypeHint(from: mediaId)
        guard let item = try? await database.fetchMediaItemResolvingAliases(id: mediaId) else {
            guard let requestedTMDBID else { return nil }
            return await localIMDbID(forTMDBID: requestedTMDBID, mediaType: hintedType)
        }

        if let hintedType, item.type != hintedType {
            guard let requestedTMDBID else { return nil }
            return await localIMDbID(forTMDBID: requestedTMDBID, mediaType: hintedType)
        }
        if let imdbID = Self.localIMDbID(from: item.id) {
            return imdbID
        }
        guard let tmdbID = item.tmdbId ?? requestedTMDBID else {
            return nil
        }
        return await localIMDbID(forTMDBID: tmdbID, mediaType: hintedType ?? item.type)
    }

    private func localIMDbID(forTMDBID tmdbID: Int, mediaType: MediaType?) async -> String? {
        guard let items = try? await database.fetchMediaItems(tmdbId: tmdbID) else {
            return nil
        }
        return items
            .filter { item in
                guard let mediaType else { return true }
                return item.type == mediaType
            }
            .compactMap { Self.localIMDbID(from: $0.id) }
            .sorted()
            .first
    }

    private static func syncIdentity(for mediaId: String) -> String {
        if let imdbID = localIMDbID(from: mediaId) {
            return imdbID
        }
        if let tmdbID = MetadataProviderIdentifierPolicy.tmdbID(from: mediaId) {
            if let type = mediaTypeHint(from: mediaId) {
                return tmdbMediaID(tmdb: tmdbID, type: type)
            }
            return "tmdb-\(tmdbID)"
        }
        return mediaId
    }

    private func localTraktSyncID(for mediaId: String) async -> String? {
        if let imdbID = await localIMDbID(for: mediaId) {
            return imdbID
        }
        return Self.preferredSyncID(from: [mediaId])
    }

    private static func preferredSyncID(from mediaIds: [String]) -> String? {
        for mediaId in mediaIds {
            if let imdbID = localIMDbID(from: mediaId) {
                return imdbID
            }
        }
        for mediaId in mediaIds {
            if let tmdbID = MetadataProviderIdentifierPolicy.tmdbID(from: mediaId) {
                if let type = mediaTypeHint(from: mediaId) {
                    return tmdbMediaID(tmdb: tmdbID, type: type)
                }
                return "tmdb-\(tmdbID)"
            }
        }
        return nil
    }

    private static func mediaIDCandidates(from item: TraktListItem) -> [String] {
        if let movieIDs = item.movie?.ids {
            return mediaIDCandidates(from: movieIDs, type: .movie)
        }
        if let showIDs = item.show?.ids {
            return mediaIDCandidates(from: showIDs, type: .series)
        }
        return []
    }

    private static func mediaIDCandidates(from ids: TraktIds?, type: MediaType? = nil) -> [String] {
        guard let ids else { return [] }
        var candidates: [String] = []
        if let imdbID = IMDbIdentifierPolicy.normalizedID(from: ids.imdb) {
            candidates.append(imdbID)
        }
        if let tmdbID = ids.tmdb {
            candidates.append(type.map { tmdbMediaID(tmdb: tmdbID, type: $0) } ?? "tmdb-\(tmdbID)")
        }
        return candidates
    }

    private static func ratingMediaIDCandidates(from item: TraktRatingItem) -> [String] {
        if let movieIDs = item.movie?.ids {
            return mediaIDCandidates(from: movieIDs, type: .movie)
        }
        if let showIDs = item.show?.ids {
            return mediaIDCandidates(from: showIDs, type: .series)
        }
        return []
    }

    private func syncIdentity(for mediaId: String) async -> String {
        if let imdbID = await localIMDbID(for: mediaId) {
            return imdbID
        }
        return Self.syncIdentity(for: mediaId)
    }

    private func syncIdentities(for mediaId: String) async -> Set<String> {
        let trimmed = mediaId.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }

        var identities: Set<String> = [Self.syncIdentity(for: trimmed)]
        if let tmdbID = MetadataProviderIdentifierPolicy.tmdbID(from: trimmed) {
            if let type = Self.mediaTypeHint(from: trimmed) {
                identities.insert(Self.tmdbMediaID(tmdb: tmdbID, type: type))
            } else {
                identities.insert("tmdb-\(tmdbID)")
            }
        }
        if let imdbID = await localIMDbID(for: trimmed) {
            identities.insert(imdbID)
        }
        return identities
    }

    private func syncIdentities(for mediaIds: [String]) async -> Set<String> {
        var identities = Set<String>()
        for mediaId in mediaIds {
            identities.formUnion(await syncIdentities(for: mediaId))
        }
        return identities
    }
}
