import Foundation
import Observation

protocol DetailMetadataProviding: Sendable {
    var detailLookupPreference: DetailMetadataLookupPreference { get }

    func getDetail(id: String, type: MediaType) async throws -> MediaItem
    func getSeasons(tmdbId: Int) async throws -> [Season]
    func getEpisodes(tmdbId: Int, season: Int) async throws -> [Episode]
    func getSeasons(id: String, type: MediaType) async throws -> [Season]
    func getEpisodes(id: String, type: MediaType, season: Int) async throws -> [Episode]
}

enum DetailMetadataLookupPreference: Sendable {
    case tmdbOrStableID
    case imdbOrTitle
}

extension DetailMetadataProviding {
    var detailLookupPreference: DetailMetadataLookupPreference { .tmdbOrStableID }
}

enum DetailMetadataLookupPolicy {
    static func detailID(
        for preview: MediaPreview,
        preference: DetailMetadataLookupPreference
    ) -> String {
        if let imdbID = IMDbIdentifierPolicy.firstID(in: preview.id) {
            return imdbID
        }

        switch preference {
        case .tmdbOrStableID:
            return preview.tmdbId.map(String.init) ?? preview.id
        case .imdbOrTitle:
            let title = preview.title.trimmingCharacters(in: .whitespacesAndNewlines)
            return title.isEmpty ? preview.id : titleLookupID(title: title, year: preview.year)
        }
    }

    static func episodeLookupID(
        for item: MediaItem,
        preference: DetailMetadataLookupPreference
    ) -> String {
        if let imdbID = IMDbIdentifierPolicy.firstID(in: item.id) {
            return imdbID
        }

        switch preference {
        case .tmdbOrStableID:
            return item.tmdbId.map { "tmdb-\($0)" } ?? item.id
        case .imdbOrTitle:
            let title = item.title.trimmingCharacters(in: .whitespacesAndNewlines)
            return title.isEmpty ? item.id : titleLookupID(title: title, year: item.year)
        }
    }

    private static func titleLookupID(title: String, year: Int?) -> String {
        guard let year, year > 0 else { return title }
        return "\(title) (\(year))"
    }
}

enum DetailMediaIdentityPolicy {
    static func imdbID(mediaItem: MediaItem?, preview: MediaPreview?) -> String? {
        IMDbIdentifierPolicy.firstID(in: mediaItem?.id) ?? IMDbIdentifierPolicy.firstID(in: preview?.id)
    }

    static func canonicalMediaID(mediaItem: MediaItem?, preview: MediaPreview?) -> String? {
        let candidateIDs = [mediaItem?.id, preview?.id]
        for candidate in candidateIDs {
            if let imdbID = IMDbIdentifierPolicy.firstID(in: candidate) {
                return imdbID
            }
        }

        for candidate in candidateIDs {
            if let trimmed = candidate?.trimmingCharacters(in: .whitespacesAndNewlines), !trimmed.isEmpty {
                return trimmed
            }
        }

        if let tmdbID = mediaItem?.tmdbId ?? preview?.tmdbId {
            return "tmdb-\(tmdbID)"
        }

        return nil
    }

    static func mediaItemPreservingLegacyAliases(_ item: MediaItem, preview: MediaPreview?) -> MediaItem {
        guard item.tmdbId == nil, let legacyTMDBID = preview?.tmdbId else {
            return item
        }
        var bridgedItem = item
        bridgedItem.tmdbId = legacyTMDBID
        return bridgedItem
    }
}

enum DetailWatchStatusState: Equatable {
    case watched
    case inProgress
    case notWatched
    case selectionRequired

    var label: String {
        switch self {
        case .watched:
            return "Watched"
        case .inProgress:
            return "In Progress"
        case .notWatched:
            return "Not watched"
        case .selectionRequired:
            return "Select an episode"
        }
    }

    var toggleButtonTitle: String? {
        switch self {
        case .watched:
            return "Mark Unwatched"
        case .inProgress, .notWatched:
            return "Mark Watched"
        case .selectionRequired:
            return nil
        }
    }

    var isWatched: Bool {
        if case .watched = self {
            return true
        }
        return false
    }
}

enum EpisodeWatchStateAliasPolicy {
    static func lookupKeys(for episode: Episode) -> [String] {
        var keys: [String] = []
        func append(_ key: String?) {
            guard let trimmed = key?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !trimmed.isEmpty,
                  !keys.contains(trimmed) else {
                return
            }
            keys.append(trimmed)
        }

        append(episode.id)
        append(TraktEpisodeIdentifierPolicy.canonicalID(from: episode.id))

        if episode.seasonNumber > 0, episode.episodeNumber > 0 {
            append(String(format: "s%02de%02d", episode.seasonNumber, episode.episodeNumber))
            append("s\(episode.seasonNumber)e\(episode.episodeNumber)")
        }

        return keys
    }

    static func watchHistory(
        for episode: Episode,
        in states: [String: WatchHistory]
    ) -> WatchHistory? {
        for key in lookupKeys(for: episode) {
            if let history = states[key] {
                return history
            }
        }
        return nil
    }
}

protocol DetailIndexerManaging: Sendable {
    func initialize() async throws
    func ensureInitialized() async throws
    func search(imdbId: String, type: MediaType, season: Int?, episode: Int?) async throws -> [TorrentResult]
    func searchByQuery(query: String, type: MediaType) async throws -> [TorrentResult]
}

extension DetailIndexerManaging {
    func ensureInitialized() async throws {
        try await initialize()
    }
}

protocol DetailDebridManaging: Sendable {
    func checkCacheAcrossServices(hashes: [String]) async throws -> [String: (CacheStatus, DebridServiceType)]
    func resolveStream(
        hash: String,
        preferredService: DebridServiceType?,
        magnetURI: String?,
        seasonNumber: Int?,
        episodeNumber: Int?
    ) async throws -> StreamInfo
    func unrestrict(link: String, serviceType: DebridServiceType) async throws -> StreamInfo
}

extension DetailDebridManaging {
    func unrestrict(link: String, serviceType: DebridServiceType) async throws -> StreamInfo {
        throw DebridError.networkError("Direct debrid link refresh is not supported.")
    }
}

protocol DetailDownloadManaging: Sendable {
    func enqueueDownload(stream: StreamInfo, mediaId: String, episodeId: String?, mediaTitle: String, mediaType: String, posterPath: String?, seasonNumber: Int?, episodeNumber: Int?, episodeTitle: String?) async throws -> DownloadTask
}

extension TMDBService: DetailMetadataProviding {}
extension OMDbService: DetailMetadataProviding {
    nonisolated var detailLookupPreference: DetailMetadataLookupPreference { .imdbOrTitle }
}
extension IndexerManager: DetailIndexerManaging {}
extension DebridManager: DetailDebridManaging {}
extension DownloadManager: DetailDownloadManaging {}

enum DetailRefreshRetentionPolicy {
    static func shouldPreserveExistingContent(
        currentMediaItem: MediaItem?,
        incomingPreview: MediaPreview
    ) -> Bool {
        guard let currentMediaItem else { return false }
        guard currentMediaItem.type == incomingPreview.type else { return false }

        if currentMediaItem.id == incomingPreview.id {
            return true
        }

        if let currentIMDbID = IMDbIdentifierPolicy.firstID(in: currentMediaItem.id),
           let incomingIMDbID = IMDbIdentifierPolicy.firstID(in: incomingPreview.id),
           currentIMDbID == incomingIMDbID {
            return true
        }

        if let currentTMDBId = currentMediaItem.tmdbId,
           let incomingTMDBId = incomingPreview.tmdbId,
           currentTMDBId == incomingTMDBId {
            return true
        }

        return false
    }
}

@Observable
@MainActor
final class DetailViewModel {
    private static let torrentResultBatchSize = 10

    var mediaItem: MediaItem?
    var seasons: [Season] = []
    var episodes: [Episode] = []
    var selectedSeason: Int = 1
    var selectedEpisode: Episode?
    /// First episode of the season immediately following `selectedSeason`, prefetched after a
    /// season loads so autoplay can continue across the season boundary (see `loadSeason`).
    private var nextSeasonFirstEpisode: Episode?
    let torrentSearch = TorrentSearchState()
    let debridResolver = DebridResolverState()
    let mediaLibrary = MediaLibraryState()
    var viewState: ViewState = .idle
    var feedbackScaleMode: FeedbackScaleMode = .likeDislike
    var currentFeedbackValue: Double?
    var aiAnalysis: AIPersonalizedAnalysis?
    var isLoadingAIAnalysis = false
    var aiAnalysisError: String?
    var downloadStates: [String: DownloadButtonState] = [:]
    var episodeWatchStates: [String: WatchHistory] = [:]
    private var downloadTaskIdsByHash: [String: String] = [:]

    // Backward-compatible mirrors for tests/callers that still bind old fields.
    var torrents: [TorrentResult] {
        get { torrentSearch.results }
        set { torrentSearch.setSearchResults(newValue, initialBatchSize: newValue.count) }
    }

    var streams: [StreamInfo] {
        get { debridResolver.streams }
        set { debridResolver.streams = newValue }
    }

    var didSearch: Bool {
        get { torrentSearch.didSearch }
        set { torrentSearch.didSearch = newValue }
    }

    var lastSearchEpisodeId: String? {
        get { torrentSearch.lastSearchEpisodeId }
        set { torrentSearch.lastSearchEpisodeId = newValue }
    }

    var lastSearchContextKey: String? {
        get { torrentSearch.lastSearchContextKey }
        set { torrentSearch.lastSearchContextKey = newValue }
    }

    var watchHistory: WatchHistory? {
        get { mediaLibrary.watchHistory }
        set { mediaLibrary.watchHistory = newValue }
    }

    var isInWatchlist: Bool {
        get { mediaLibrary.isInWatchlist }
        set { mediaLibrary.isInWatchlist = newValue }
    }

    var isInFavorites: Bool {
        get { mediaLibrary.isInFavorites }
        set { mediaLibrary.isInFavorites = newValue }
    }

    var watchlistFolders: [LibraryFolder] {
        get { mediaLibrary.watchlistFolders }
        set { mediaLibrary.watchlistFolders = newValue }
    }

    var favoriteFolders: [LibraryFolder] {
        get { mediaLibrary.favoriteFolders }
        set { mediaLibrary.favoriteFolders = newValue }
    }

    var libraryStatusMessage: String? {
        get { mediaLibrary.statusMessage }
        set { mediaLibrary.statusMessage = newValue }
    }

    var error: AppError? {
        get {
            guard case .error(let appError) = viewState else { return nil }
            return appError
        }
        set {
            guard let newValue else {
                if case .error = viewState {
                    viewState = .idle
                }
                return
            }
            viewState = .error(newValue)
        }
    }

    var isLoadingDetail: Bool { isLoading(.detail) || isLoading(.seasonEpisodes) }
    var isLoadingTorrents: Bool { isLoading(.torrentSearch) }
    var isResolvingStream: Bool { isLoading(.streamResolution) || isLoading(.downloadQueue) }

    /// Non-special (season > 0) episode watch tally for the whole series. The total comes from
    /// season metadata so it's accurate even before every season's episodes are loaded; specials
    /// (season 0) are excluded per product spec.
    var seriesWatchTally: (watched: Int, total: Int) {
        let total = seasons
            .filter { $0.seasonNumber > 0 }
            .map(\.episodeCount)
            .reduce(0, +)
        let watched = regularWatchedEpisodeCount()
        return (watched, total)
    }

    /// True when every aired regular episode of the series is watched (auto-derived from the
    /// ≥90% per-episode completion state — no manual marking required).
    var isSeriesFullyWatched: Bool {
        let tally = seriesWatchTally
        return tally.total > 0 && tally.watched >= tally.total
    }
    var currentFeedbackSummary: String? {
        guard let currentFeedbackValue else { return nil }
        return feedbackScaleMode.format(currentFeedbackValue)
    }
    var loadingPhase: LoadingPhase? {
        guard case .loading(let phase) = viewState else { return nil }
        return phase
    }

    private let appState: AppState
    private let metadataProviderFactory: @Sendable (String) -> any DetailMetadataProviding
    private let indexerManager: any DetailIndexerManaging
    private let debridManager: any DetailDebridManaging
    private let downloadManager: any DetailDownloadManaging
    private var previewContext: MediaPreview?
    private var currentMetadataAPIKey = ""
    private var searchTask: Task<Void, Never>?
    private var cacheEnrichmentTask: Task<Void, Never>?
    private var detailLoadGeneration = 0
    private var seasonLoadGeneration = 0
    private var lastFailedPhase: LoadingPhase?
    private var lastFailedTorrent: TorrentResult?

    var requiresFreshEpisodeSearch: Bool {
        guard mediaItem?.type == .series else { return false }
        guard torrentSearch.didSearch else { return false }
        guard let mediaID = currentMediaIdentifier else { return false }
        let currentContext = searchContextKey(
            mediaID: mediaID,
            season: selectedSeason,
            episode: selectedEpisode?.episodeNumber
        )
        return currentContext != torrentSearch.lastSearchContextKey
    }

    var canLoadMoreTorrents: Bool { torrentSearch.canLoadMoreResults }
    var remainingTorrentCount: Int { torrentSearch.remainingResultCount }
    var nextTorrentBatchCount: Int { min(Self.torrentResultBatchSize, remainingTorrentCount) }
    private var currentMediaIdentifier: String? {
        DetailMediaIdentityPolicy.canonicalMediaID(mediaItem: mediaItem, preview: previewContext)
    }

    var currentWatchStatusState: DetailWatchStatusState {
        guard let mediaType = mediaItem?.type ?? previewContext?.type else {
            return .notWatched
        }

        if mediaType == .series {
            guard let selectedEpisode else {
                return .selectionRequired
            }
            return isEpisodeWatched(selectedEpisode) ? .watched : .notWatched
        }

        guard let watchHistory = mediaLibrary.watchHistory else {
            return .notWatched
        }

        if watchHistory.isCompleted {
            return .watched
        }

        if watchHistory.progressPercent > 0.02 {
            return .inProgress
        }

        return .notWatched
    }

    init(
        appState: AppState,
        metadataProviderFactory: (@Sendable (String) -> any DetailMetadataProviding)? = nil,
        indexerManager: (any DetailIndexerManaging)? = nil,
        debridManager: (any DetailDebridManaging)? = nil,
        downloadManager: (any DetailDownloadManaging)? = nil
    ) {
        self.appState = appState
        self.metadataProviderFactory = metadataProviderFactory ?? { apiKey in
            OMDbService(apiKey: apiKey)
        }
        self.indexerManager = indexerManager ?? appState.indexerManager
        self.debridManager = debridManager ?? appState.debridManager
        self.downloadManager = downloadManager ?? appState.downloadManager
    }

    func setPreviewContext(_ preview: MediaPreview) {
        previewContext = preview
    }

    func cancelInFlightWork() {
        searchTask?.cancel()
        searchTask = nil
        cacheEnrichmentTask?.cancel()
        cacheEnrichmentTask = nil
    }

    func loadMoreTorrentResults() {
        _ = torrentSearch.revealMoreResults(batchSize: Self.torrentResultBatchSize)
    }

    func loadDetail(preview: MediaPreview, apiKey: String) async {
        currentMetadataAPIKey = apiKey
        let shouldPreserveExistingContent = DetailRefreshRetentionPolicy.shouldPreserveExistingContent(
            currentMediaItem: mediaItem,
            incomingPreview: preview
        )

        cancelInFlightWork()
        previewContext = preview
        let detailGeneration = nextDetailLoadGeneration()
        _ = nextSeasonLoadGeneration()
        beginLoading(.detail)

        if !shouldPreserveExistingContent {
            prepareForDetailLoad(preview: preview)
        }

        let service = metadataProviderFactory(apiKey)

        do {
            let detailID = DetailMetadataLookupPolicy.detailID(
                for: preview,
                preference: service.detailLookupPreference
            )
            let fetchedItem = try await service.getDetail(id: detailID, type: preview.type)
            guard isCurrentDetailLoad(detailGeneration) else { return }
            let item = DetailMediaIdentityPolicy.mediaItemPreservingLegacyAliases(
                fetchedItem,
                preview: preview
            )
            self.mediaItem = item

            // Cache in database
            try? await appState.database.saveMediaItem(item)

            // Load watch history
            if let mediaIdentifier = currentMediaIdentifier {
                mediaLibrary.watchHistory = try? await appState.database.fetchWatchHistory(mediaId: mediaIdentifier)
            }

            // Load seasons for TV shows
            var prefetchAfterSeason: (lookupID: String, season: Int)?
            if preview.type == .series {
                let lookupID = DetailMetadataLookupPolicy.episodeLookupID(
                    for: item,
                    preference: service.detailLookupPreference
                )
                let loadedSeasons = try await service.getSeasons(id: lookupID, type: item.type)
                guard isCurrentDetailLoad(detailGeneration) else { return }
                seasons = loadedSeasons
                if let initialSeason = resolveInitialSeason(preview: preview) {
                    selectedSeason = initialSeason
                    nextSeasonFirstEpisode = nil
                    let loadedEpisodes = try await service.getEpisodes(id: lookupID, type: item.type, season: initialSeason)
                    guard isCurrentDetailLoad(detailGeneration) else { return }
                    episodes = loadedEpisodes
                    selectedEpisode = resolveInitialEpisode(in: episodes, preview: preview)
                    // episodeWatchStates loaded via reloadLibraryState() -> refreshWatchHistoryState() below
                    prefetchAfterSeason = (lookupID, initialSeason)
                }
            }

            async let libraryState: Void = reloadLibraryState()
            async let feedbackState: Void = refreshFeedbackState()
            _ = await (libraryState, feedbackState)
            guard isCurrentDetailLoad(detailGeneration) else { return }
            markLoaded()

            // Prefetch the next season's first episode AFTER the detail page is shown so the
            // opening flow (which loads the initial season here, not via loadSeason) can still
            // cross the season boundary at a finale. Best-effort and guarded by the detail-load
            // generation; runs only when the initial season is still the selected one.
            if let prefetchAfterSeason {
                await prefetchNextSeasonFirstEpisode(
                    afterSeason: prefetchAfterSeason.season,
                    lookupID: prefetchAfterSeason.lookupID,
                    type: item.type,
                    service: service,
                    isStillCurrent: { [weak self] in
                        guard let self else { return false }
                        return self.isCurrentDetailLoad(detailGeneration)
                            && self.selectedSeason == prefetchAfterSeason.season
                    }
                )
            }
        } catch {
            guard isCurrentDetailLoad(detailGeneration) else { return }
            setError(error, fallback: .network(.transport(error.localizedDescription)))
            async let libraryState: Void = reloadLibraryState()
            async let feedbackState: Void = refreshFeedbackState()
            _ = await (libraryState, feedbackState)
        }
    }

    private func prepareForDetailLoad(preview: MediaPreview) {
        mediaItem = nil
        seasons = []
        episodes = []
        selectedEpisode = nil
        selectedSeason = preview.seasonNumber ?? 1
        lastFailedTorrent = nil

        torrentSearch.setSearchResults([], initialBatchSize: 0)
        torrentSearch.didSearch = false
        torrentSearch.lastSearchEpisodeId = nil
        torrentSearch.lastSearchContextKey = nil
    }

    private func resolveInitialSeason(preview: MediaPreview) -> Int? {
        let availableSeasons = Set(seasons.map(\.seasonNumber))

        if let seasonNumber = preview.seasonNumber, availableSeasons.contains(seasonNumber) {
            return seasonNumber
        }

        if let parsedSeason = parseSeasonAndEpisode(from: preview.episodeId)?.seasonNumber,
           availableSeasons.contains(parsedSeason) {
            return parsedSeason
        }

        if let recentEpisodeId = mediaLibrary.watchHistory?.episodeId,
           let parsedSeason = parseSeasonAndEpisode(from: recentEpisodeId)?.seasonNumber,
           availableSeasons.contains(parsedSeason) {
            return parsedSeason
        }

        return seasons.first?.seasonNumber
    }

    private func resolveInitialEpisode(in episodes: [Episode], preview: MediaPreview) -> Episode? {
        if let previewEpisodeId = preview.episodeId,
           let matchingEpisode = episodes.first(where: { $0.id == previewEpisodeId }) {
            return matchingEpisode
        }

        if let previewEpisodeNumber = preview.episodeNumber,
           let matchingEpisode = episodes.first(where: { $0.episodeNumber == previewEpisodeNumber }) {
            return matchingEpisode
        }

        if let previewEpisodeId = preview.episodeId,
           let parsedEpisode = parseSeasonAndEpisode(from: previewEpisodeId)?.episodeNumber,
           let matchingEpisode = episodes.first(where: { $0.episodeNumber == parsedEpisode }) {
            return matchingEpisode
        }

        if let recentEpisodeId = mediaLibrary.watchHistory?.episodeId {
            if let matchingEpisode = episodes.first(where: { $0.id == recentEpisodeId }) {
                return matchingEpisode
            }

            if let parsedEpisode = parseSeasonAndEpisode(from: recentEpisodeId)?.episodeNumber,
               let matchingEpisode = episodes.first(where: { $0.episodeNumber == parsedEpisode }) {
                return matchingEpisode
            }
        }

        return nil
    }

    private func parseSeasonAndEpisode(from episodeId: String?) -> (seasonNumber: Int, episodeNumber: Int)? {
        guard let context = TraktEpisodeIdentifierPolicy.seasonEpisode(from: episodeId) else { return nil }
        return (context.season, context.episode)
    }

    private func regularWatchedEpisodeCount() -> Int {
        let loadedRegularEpisodeIDs = Set(
            episodes
                .filter { $0.seasonNumber > 0 }
                .map(\.id)
        )

        return episodeWatchStates.reduce(into: 0) { count, item in
            let episodeId = item.key
            let history = item.value
            guard history.isCompleted else { return }

            if loadedRegularEpisodeIDs.contains(episodeId) {
                count += 1
                return
            }

            // Imported/synced history often uses synthetic IDs such as "...-s1e2".
            // OMDb episode IDs are IMDb IDs, so they are counted only when the
            // loaded episode list proves the season relationship above.
            guard let parsed = parseSeasonAndEpisode(from: episodeId),
                  parsed.seasonNumber > 0 else {
                return
            }
            count += 1
        }
    }

    func watchHistory(for episode: Episode) -> WatchHistory? {
        EpisodeWatchStateAliasPolicy.watchHistory(for: episode, in: episodeWatchStates)
    }

    func isEpisodeWatched(_ episode: Episode) -> Bool {
        watchHistory(for: episode)?.isCompleted == true
    }

    private func episodeWatchStateLookupKeys(for episode: Episode) -> [String] {
        EpisodeWatchStateAliasPolicy.lookupKeys(for: episode)
    }

    private func markEpisodeUnwatchedAcrossKnownAliases(
        mediaId: String,
        episode: Episode
    ) async throws {
        for episodeId in episodeWatchStateLookupKeys(for: episode) {
            try await appState.database.markEpisodeUnwatched(mediaId: mediaId, episodeId: episodeId)
        }
    }

    func loadSeason(_ seasonNumber: Int, apiKey: String) async {
        guard let item = mediaItem else { return }
        guard selectedSeason != seasonNumber || episodes.isEmpty else { return }

        currentMetadataAPIKey = apiKey
        cancelInFlightWork()
        let seasonGeneration = nextSeasonLoadGeneration()
        selectedSeason = seasonNumber
        episodes = []
        selectedEpisode = nil
        nextSeasonFirstEpisode = nil
        invalidateSearchResultsForEpisodeChange()
        beginLoading(.seasonEpisodes)

        let service = metadataProviderFactory(apiKey)
        do {
            let lookupID = DetailMetadataLookupPolicy.episodeLookupID(
                for: item,
                preference: service.detailLookupPreference
            )
            let loadedEpisodes = try await service.getEpisodes(id: lookupID, type: item.type, season: seasonNumber)
            guard isCurrentSeasonLoad(seasonGeneration, seasonNumber: seasonNumber) else { return }
            episodes = loadedEpisodes
            selectedEpisode = nil
            await loadEpisodeWatchStates()
            guard isCurrentSeasonLoad(seasonGeneration, seasonNumber: seasonNumber) else { return }
            markLoaded()
            await prefetchNextSeasonFirstEpisode(
                afterSeason: seasonNumber,
                lookupID: lookupID,
                type: item.type,
                service: service,
                isStillCurrent: { [weak self] in
                    self?.isCurrentSeasonLoad(seasonGeneration, seasonNumber: seasonNumber) ?? false
                }
            )
        } catch {
            guard isCurrentSeasonLoad(seasonGeneration, seasonNumber: seasonNumber) else { return }
            setError(error, fallback: .network(.transport(error.localizedDescription)))
        }
    }

    /// Best-effort prefetch of the next season's first episode so autoplay can cross the season
    /// boundary at a finale. Runs only after the visible season has already loaded, never throws
    /// into the load flow, and re-checks `isStillCurrent` after the fetch so a stale result cannot
    /// overwrite state after the user has navigated away. Both the initial `loadDetail` path and a
    /// later `loadSeason` tab switch call this, each passing the guard appropriate to its own
    /// load generation.
    private func prefetchNextSeasonFirstEpisode(
        afterSeason loadedSeason: Int,
        lookupID: String,
        type: MediaType,
        service: any DetailMetadataProviding,
        isStillCurrent: @escaping () -> Bool
    ) async {
        guard let nextSeason = DetailNextEpisodePolicy.prefetchSeasonNumber(
            after: loadedSeason,
            seasons: seasons
        ) else {
            return
        }
        guard let nextSeasonEpisodes = try? await service.getEpisodes(id: lookupID, type: type, season: nextSeason) else {
            return
        }
        guard isStillCurrent() else { return }
        nextSeasonFirstEpisode = DetailNextEpisodePolicy.firstEpisode(of: nextSeasonEpisodes)
    }

    func retryLastFailedOperation(apiKey: String) async {
        switch lastFailedPhase {
        case .detail:
            guard let previewContext else { return }
            await loadDetail(preview: previewContext, apiKey: apiKey)
        case .seasonEpisodes:
            await loadSeason(selectedSeason, apiKey: apiKey)
        case .torrentSearch:
            await searchTorrents()
        case .librarySync:
            await reloadLibraryState()
        case .streamResolution:
            guard let failedTorrent = lastFailedTorrent else {
                clearError()
                return
            }
            _ = await resolveStream(torrent: failedTorrent)
        case .downloadQueue:
            guard let failedTorrent = lastFailedTorrent else {
                clearError()
                return
            }
            await queueDownload(torrent: failedTorrent)
        case .none:
            clearError()
        }
    }

    func selectEpisode(_ episode: Episode) {
        guard selectedEpisode?.id != episode.id else { return }
        cancelInFlightWork()
        selectedEpisode = episode
        invalidateSearchResultsForEpisodeChange()
    }

    func searchTorrents() async {
        guard let item = mediaItem else { return }
        searchTask?.cancel()
        cacheEnrichmentTask?.cancel()
        beginLoading(.torrentSearch)

        let season: Int? = item.type == .series ? selectedSeason : nil
        let episode: Int? = item.type == .series ? selectedEpisode?.episodeNumber : nil
        let searchedEpisodeId = item.type == .series ? selectedEpisode?.id : nil
        let mediaIdentifier = currentMediaIdentifier ?? item.id
        let contextKey = searchContextKey(mediaID: mediaIdentifier, season: season, episode: episode)
        let query = buildQuery(for: item, season: season, episode: episode)
        let indexerManager = self.indexerManager

        searchTask = Task { [weak self] in
            do {
                try Task.checkCancellation()
                try await indexerManager.ensureInitialized()

                var results: [TorrentResult] = []
                var primaryError: Error?

                if let imdbID = IMDbIdentifierPolicy.firstID(in: mediaIdentifier) ?? IMDbIdentifierPolicy.firstID(in: item.id) {
                    do {
                        results = try await indexerManager.search(
                            imdbId: imdbID,
                            type: item.type,
                            season: season,
                            episode: episode
                        )
                    } catch {
                        primaryError = error
                    }
                }

                try Task.checkCancellation()

                if results.isEmpty {
                    do {
                        results = try await indexerManager.searchByQuery(
                            query: query,
                            type: item.type
                        )
                    } catch {
                        if let primaryError {
                            throw primaryError
                        }
                        throw error
                    }
                }

                try Task.checkCancellation()
                guard let self else { return }
                let sourceFilterOptions = await self.sourceFilterOptionsFromSettings()
                results = await self.sortTorrentsByPreferences(results)
                let latestMediaIdentifier = self.currentMediaIdentifier ?? item.id
                let latestContext = self.searchContextKey(
                    mediaID: latestMediaIdentifier,
                    season: item.type == .series ? self.selectedSeason : nil,
                    episode: item.type == .series ? self.selectedEpisode?.episodeNumber : nil
                )
                guard latestContext == contextKey else { return }
                self.torrentSearch.setSourceFilterOptions(sourceFilterOptions)
                self.torrentSearch.setSearchResults(results, initialBatchSize: Self.torrentResultBatchSize)
                self.torrentSearch.markCompletedSearch(episodeId: searchedEpisodeId, contextKey: contextKey)
                self.markLoaded()
                self.startCacheEnrichment(contextKey: contextKey)
            } catch is CancellationError {
                // Silently discard cancelled search — a newer search is in progress.
            } catch {
                guard let self else { return }
                self.setError(error, fallback: .indexer(.queryFailed(error.localizedDescription)))
            }
        }
        await searchTask?.value
    }

    private static let cacheBatchSize = 20

    private func startCacheEnrichment(contextKey: String) {
        cacheEnrichmentTask?.cancel()
        let hashes = torrentSearch.allHashes
        guard !hashes.isEmpty else { return }

        cacheEnrichmentTask = Task { [debridManager, weak self] in
            for batchStart in stride(from: 0, to: hashes.count, by: Self.cacheBatchSize) {
                try? Task.checkCancellation()
                guard !Task.isCancelled else { return }

                let batchEnd = min(batchStart + Self.cacheBatchSize, hashes.count)
                let batch = Array(hashes[batchStart..<batchEnd])

                guard let cacheResults = try? await debridManager.checkCacheAcrossServices(hashes: batch) else {
                    continue
                }
                guard !Task.isCancelled else { return }
                guard self?.torrentSearch.lastSearchContextKey == contextKey else { return }
                self?.torrentSearch.updateCacheStatus(cacheResults)
            }
        }
    }

    /// Awaits the in-flight cache-enrichment pass (best-effort, bounded by
    /// `timeout`) then returns the highest-priority confirmed-cached source, or
    /// `nil` when none are cached. Used by one-tap play (`.playBestCached`) so it
    /// never force-plays an uncached source. Cache status arrives asynchronously
    /// after `searchTorrents()`; awaiting the enrichment task lets a fresh result
    /// set settle before selection, while `timeout` guards against a stalled
    /// debrid check (on timeout we select from whatever has been confirmed so
    /// far, which may be `nil`).
    func bestCachedTorrent(timeout: Duration = .seconds(12)) async -> TorrentResult? {
        if let enrichment = cacheEnrichmentTask {
            await withTaskGroup(of: Void.self) { group in
                group.addTask { await enrichment.value }
                group.addTask { try? await Task.sleep(for: timeout) }
                _ = await group.next()
                group.cancelAll()
            }
        }
        return DetailPlaybackSelectionPolicy.bestCachedResult(from: torrentSearch.allResultsSnapshot)
    }

    func resolveStream(torrent: TorrentResult) async -> StreamInfo? {
        beginLoading(.streamResolution)
        defer { finishLoadingIfNeeded(for: .streamResolution) }

        if let directStream = immediateDirectStream(for: torrent) {
            let stream = attachDirectStreamRecoveryContextIfPossible(
                to: directStream,
                torrent: torrent,
                preferredService: nil,
                seasonNumber: mediaItem?.type == .series ? selectedEpisode?.seasonNumber : nil,
                episodeNumber: mediaItem?.type == .series ? selectedEpisode?.episodeNumber : nil
            )
            debridResolver.appendStreamIfNeeded(stream)
            lastFailedTorrent = nil
            return stream
        }

        do {
            let preferredService = torrent.cachedOnService.flatMap(DebridServiceType.init(rawValue:))
            let seasonNumber = mediaItem?.type == .series ? selectedEpisode?.seasonNumber : nil
            let episodeNumber = mediaItem?.type == .series ? selectedEpisode?.episodeNumber : nil
            let resolvedStream = try await debridManager.resolveStream(
                hash: torrent.infoHash,
                preferredService: preferredService,
                magnetURI: torrent.magnetURI,
                seasonNumber: seasonNumber,
                episodeNumber: episodeNumber
            )
            let stream = attachRecoveryContext(
                to: resolvedStream,
                torrent: torrent,
                preferredService: preferredService,
                seasonNumber: seasonNumber,
                episodeNumber: episodeNumber
            )
            debridResolver.appendStreamIfNeeded(stream)
            lastFailedTorrent = nil
            return stream
        } catch {
            lastFailedTorrent = torrent
            setError(error, fallback: .debrid(.networkError(error.localizedDescription)))
            return nil
        }
    }

    func queueDownload(torrent: TorrentResult) async {
        guard let item = mediaItem else { return }
        let mediaIdentifier = currentMediaIdentifier ?? item.id
        let hash = torrent.infoHash
        let episodeId = item.type == .series ? selectedEpisode?.id : nil
        downloadStates[hash] = .resolving
        beginLoading(.downloadQueue)
        defer { finishLoadingIfNeeded(for: .downloadQueue) }

        do {
            let seasonNumber = item.type == .series ? selectedEpisode?.seasonNumber : nil
            let episodeNumber = item.type == .series ? selectedEpisode?.episodeNumber : nil
            let stream: StreamInfo
            if let directStream = immediateDirectStream(for: torrent) {
                stream = attachDirectStreamRecoveryContextIfPossible(
                    to: directStream,
                    torrent: torrent,
                    preferredService: nil,
                    seasonNumber: seasonNumber,
                    episodeNumber: episodeNumber
                )
            } else {
                let preferredService = torrent.cachedOnService.flatMap(DebridServiceType.init(rawValue:))
                let resolvedStream = try await debridManager.resolveStream(
                    hash: torrent.infoHash,
                    preferredService: preferredService,
                    magnetURI: torrent.magnetURI,
                    seasonNumber: seasonNumber,
                    episodeNumber: episodeNumber
                )
                stream = attachRecoveryContext(
                    to: resolvedStream,
                    torrent: torrent,
                    preferredService: preferredService,
                    seasonNumber: seasonNumber,
                    episodeNumber: episodeNumber
                )
            }
            guard mediaItem?.id == item.id else { return }
            downloadStates[hash] = .downloading
            let enqueuedTask = try await downloadManager.enqueueDownload(
                stream: stream,
                mediaId: mediaIdentifier,
                episodeId: episodeId,
                mediaTitle: item.title,
                mediaType: item.type.rawValue,
                posterPath: item.posterPath,
                seasonNumber: seasonNumber,
                episodeNumber: episodeNumber,
                episodeTitle: item.type == .series ? selectedEpisode?.title : nil
            )
            downloadTaskIdsByHash[hash] = enqueuedTask.id
            mediaLibrary.statusMessage = "Added to downloads."
            lastFailedTorrent = nil
        } catch {
            lastFailedTorrent = torrent
            downloadStates[hash] = .failed
            setError(error, fallback: .debrid(.networkError(error.localizedDescription)))
        }
    }

    func downloadState(for torrent: TorrentResult) -> DownloadButtonState {
        downloadStates[torrent.infoHash] ?? .idle
    }

    private func immediateDirectStream(for torrent: TorrentResult) -> StreamInfo? {
        guard let directStream = torrent.directStreamInfo else { return nil }
        guard !torrent.prefersDebridResolutionOverDirectURL else { return nil }
        return directStream
    }

    func refreshDownloadStates() async {
        guard !downloadTaskIdsByHash.isEmpty else { return }
        let allTasks = (try? await appState.downloadManager.listDownloads()) ?? []
        let taskById = Dictionary(uniqueKeysWithValues: allTasks.map { ($0.id, $0) })

        for (hash, taskId) in downloadTaskIdsByHash {
            guard let task = taskById[taskId] else { continue }
            switch task.status {
            case .completed:
                downloadStates[hash] = .completed
            case .failed, .cancelled:
                downloadStates[hash] = .failed
            case .downloading, .resolving, .queued:
                downloadStates[hash] = .downloading
            }
        }
    }

    func toggleWatchlist() async {
        await toggleLibraryMembership(for: .watchlist)
    }

    func toggleFavorites() async {
        await toggleLibraryMembership(for: .favorites)
    }

    func addOrMoveToLibrary(
        listType: UserLibraryEntry.ListType,
        folderId: String,
        folderName: String? = nil
    ) async {
        let mediaIdentifier = currentMediaIdentifier
        guard let mediaIdentifier else {
            mediaLibrary.statusMessage = "Library update failed: missing media identifier."
            return
        }

        beginLoading(.librarySync)
        defer { finishLoadingIfNeeded(for: .librarySync) }

        do {
            let resolvedFolderID: String
            if folderId.isEmpty {
                resolvedFolderID = try await appState.database.fetchSystemLibraryFolderID(listType: listType)
            } else {
                resolvedFolderID = folderId
            }

            let alreadyInList = try await appState.database.isInLibrary(mediaId: mediaIdentifier, listType: listType)
            let targetFolderName = folderName ?? resolvedFolderName(for: listType, folderId: resolvedFolderID)
            let isRootFolder = targetFolderName.localizedCaseInsensitiveCompare(listType.displayName) == .orderedSame

            if alreadyInList {
                guard listType.supportsFolders else { return }
                try await appState.database.moveLibraryEntry(
                    mediaId: mediaIdentifier,
                    listType: listType,
                    toFolderId: resolvedFolderID
                )

                mediaLibrary.statusMessage = isRootFolder
                    ? "Moved within \(listType.displayName)."
                    : "Moved to \(targetFolderName) in \(listType.displayName)."
            } else {
                let entry = UserLibraryEntry(
                    id: "\(mediaIdentifier)-\(listType.rawValue)",
                    mediaId: mediaIdentifier,
                    folderId: resolvedFolderID,
                    listType: listType,
                    addedAt: Date()
                )
                try await appState.database.addToLibrary(entry)
                mediaLibrary.statusMessage = isRootFolder
                    ? "Added to \(listType.displayName.lowercased())."
                    : "Added to \(targetFolderName) in \(listType.displayName)."
            }

            await refreshLibraryState()
            NotificationCenter.default.post(name: .libraryDidChange, object: nil)
        } catch {
            handleLibraryError(error, fallbackPrefix: "Library update failed")
        }
    }

    func removeFromLibrary(listType: UserLibraryEntry.ListType) async {
        let mediaIdentifier = currentMediaIdentifier
        guard let mediaIdentifier else {
            mediaLibrary.statusMessage = "Library update failed: missing media identifier."
            return
        }

        beginLoading(.librarySync)
        defer { finishLoadingIfNeeded(for: .librarySync) }

        do {
            try await appState.database.removeFromLibrary(mediaId: mediaIdentifier, listType: listType)
            mediaLibrary.statusMessage = "Removed from \(listType.displayName.lowercased())."
            await refreshLibraryState()
            NotificationCenter.default.post(name: .libraryDidChange, object: nil)
        } catch {
            handleLibraryError(error, fallbackPrefix: "Library update failed")
        }
    }

    func reloadLibraryState() async {
        await refreshLibraryState()
        await refreshWatchHistoryState()
    }

    func submitFeedback(value: Double) async {
        let mediaIdentifier = currentMediaIdentifier
        guard let mediaIdentifier else {
            mediaLibrary.statusMessage = "Rating failed: missing media identifier."
            return
        }

        beginLoading(.librarySync)
        defer { finishLoadingIfNeeded(for: .librarySync) }

        do {
            let selectedScale = (try? await appState.settingsManager.getFeedbackScaleMode()) ?? .likeDislike
            let canonicalScale = selectedScale.canonicalMode
            let clampedValue = canonicalScale.clamp(value)
            let normalized = canonicalScale.normalizedValue(clampedValue)
            let title = mediaItem?.title ?? previewContext?.title ?? "Untitled"

            let event = TasteEvent(
                userId: "default",
                mediaId: mediaIdentifier,
                episodeId: nil,
                eventType: .rated,
                signalStrength: normalized,
                watchedState: nil,
                feedbackScale: canonicalScale,
                feedbackValue: clampedValue,
                source: .manual,
                metadata: ["title": title]
            )
            try await appState.database.saveTasteEvent(event)

            feedbackScaleMode = canonicalScale
            currentFeedbackValue = clampedValue
            mediaLibrary.statusMessage = "Saved rating: \(canonicalScale.format(clampedValue))."

            NotificationCenter.default.post(name: .tasteProfileDidChange, object: nil)
        } catch {
            let appError = AppError(error, fallback: .unknown("Rating update failed: \(error.localizedDescription)"))
            mediaLibrary.statusMessage = appError.errorDescription
            viewState = .error(appError)
        }
    }

    func clearFeedback() async {
        let mediaIdentifier = currentMediaIdentifier
        guard let mediaIdentifier else {
            mediaLibrary.statusMessage = "Clear rating failed: missing media identifier."
            return
        }

        beginLoading(.librarySync)
        defer { finishLoadingIfNeeded(for: .librarySync) }

        do {
            try await appState.database.deleteLatestTasteRating(mediaId: mediaIdentifier)
            currentFeedbackValue = nil
            mediaLibrary.statusMessage = "Rating cleared."
            NotificationCenter.default.post(name: .tasteProfileDidChange, object: nil)
        } catch {
            let appError = AppError(error, fallback: .unknown("Clear rating failed: \(error.localizedDescription)"))
            mediaLibrary.statusMessage = appError.errorDescription
            viewState = .error(appError)
        }
    }

    func reloadFeedbackState() async {
        await refreshFeedbackState()
    }

    func fetchAIAnalysis() async {
        guard let item = mediaItem else { return }
        isLoadingAIAnalysis = true
        aiAnalysisError = nil

        do {
            let analysis = try await appState.aiAssistantManager.getPersonalizedAnalysis(
                title: item.title,
                year: item.year,
                type: item.type,
                genres: item.genres,
                overview: item.overview
            )
            aiAnalysis = analysis
        } catch let error as AIError {
            switch error {
            case .noProviderConfigured:
                aiAnalysisError = "No AI provider configured. Set one up in Settings \u{2192} AI Assistant."
            default:
                aiAnalysisError = error.localizedDescription
            }
        } catch {
            aiAnalysisError = error.localizedDescription
        }

        isLoadingAIAnalysis = false
    }

    func loadEpisodeWatchStates() async {
        guard let mediaItem, mediaItem.type == .series else { return }
        guard let mediaIdentifier = currentMediaIdentifier else { return }
        let freshStates = (try? await appState.database.fetchEpisodeWatchStates(mediaId: mediaIdentifier)) ?? [:]
        if freshStates != episodeWatchStates {
            episodeWatchStates = freshStates
        }
    }

    func toggleEpisodeWatched(_ episode: Episode) async {
        guard mediaItem != nil else { return }
        guard let mediaIdentifier = currentMediaIdentifier else { return }
        let wasWatched = isEpisodeWatched(episode)

        beginLoading(.librarySync)
        defer { finishLoadingIfNeeded(for: .librarySync) }

        do {
            if wasWatched {
                try await markEpisodeUnwatchedAcrossKnownAliases(mediaId: mediaIdentifier, episode: episode)
            } else {
                try await appState.database.markEpisodeWatched(
                    mediaId: mediaIdentifier,
                    episodeId: episode.id,
                    title: episode.displayTitle
                )
            }
            await refreshWatchHistoryState()
            mediaLibrary.statusMessage = wasWatched ? "Marked as not watched." : "Marked as watched."
            NotificationCenter.default.post(name: .watchHistoryDidChange, object: nil)
        } catch {
            handleLibraryError(error, fallbackPrefix: "Watch state update failed")
        }
    }

    func markSeasonWatched() async {
        guard let mediaIdentifier = currentMediaIdentifier else { return }

        beginLoading(.librarySync)
        defer { finishLoadingIfNeeded(for: .librarySync) }

        do {
            for episode in episodes where !isEpisodeWatched(episode) {
                try await appState.database.markEpisodeWatched(
                    mediaId: mediaIdentifier,
                    episodeId: episode.id,
                    title: episode.displayTitle
                )
            }
            await refreshWatchHistoryState()
            mediaLibrary.statusMessage = "Marked season as watched."
            NotificationCenter.default.post(name: .watchHistoryDidChange, object: nil)
        } catch {
            handleLibraryError(error, fallbackPrefix: "Watch state update failed")
        }
    }

    func markSeasonUnwatched() async {
        guard let mediaIdentifier = currentMediaIdentifier else { return }

        beginLoading(.librarySync)
        defer { finishLoadingIfNeeded(for: .librarySync) }

        do {
            for episode in episodes {
                try await markEpisodeUnwatchedAcrossKnownAliases(mediaId: mediaIdentifier, episode: episode)
            }
            await refreshWatchHistoryState()
            mediaLibrary.statusMessage = "Marked season as not watched."
            NotificationCenter.default.post(name: .watchHistoryDidChange, object: nil)
        } catch {
            handleLibraryError(error, fallbackPrefix: "Watch state update failed")
        }
    }

    func markSeriesWatched() async {
        guard let mediaItem, mediaItem.type == .series else { return }
        guard let mediaIdentifier = currentMediaIdentifier else { return }

        beginLoading(.librarySync)
        defer { finishLoadingIfNeeded(for: .librarySync) }

        do {
            let allEpisodes = try await fetchAllEpisodesForSeries()
            guard !allEpisodes.isEmpty else {
                mediaLibrary.statusMessage = "No episodes available to mark yet."
                return
            }

            for episode in allEpisodes where !isEpisodeWatched(episode) {
                try await appState.database.markEpisodeWatched(
                    mediaId: mediaIdentifier,
                    episodeId: episode.id,
                    title: episode.displayTitle
                )
            }
            await refreshWatchHistoryState()
            mediaLibrary.statusMessage = "Marked series as watched."
            NotificationCenter.default.post(name: .watchHistoryDidChange, object: nil)
        } catch {
            handleLibraryError(error, fallbackPrefix: "Watch state update failed")
        }
    }

    func markSeriesUnwatched() async {
        guard let mediaItem, mediaItem.type == .series else { return }
        guard let mediaIdentifier = currentMediaIdentifier else { return }

        beginLoading(.librarySync)
        defer { finishLoadingIfNeeded(for: .librarySync) }

        do {
            try await appState.database.markSeriesUnwatched(mediaId: mediaIdentifier)
            await refreshWatchHistoryState()
            mediaLibrary.statusMessage = "Marked series as not watched."
            NotificationCenter.default.post(name: .watchHistoryDidChange, object: nil)
        } catch {
            handleLibraryError(error, fallbackPrefix: "Watch state update failed")
        }
    }

    func toggleCurrentWatchState() async {
        guard let mediaItem else { return }
        guard let mediaIdentifier = currentMediaIdentifier else { return }
        let priorState = currentWatchStatusState
        guard priorState != .selectionRequired else {
            mediaLibrary.statusMessage = "Select an episode first."
            return
        }

        beginLoading(.librarySync)
        defer { finishLoadingIfNeeded(for: .librarySync) }

        do {
            if mediaItem.type == .series {
                guard let selectedEpisode else { return }
                if priorState.isWatched {
                    try await markEpisodeUnwatchedAcrossKnownAliases(mediaId: mediaIdentifier, episode: selectedEpisode)
                } else {
                    try await appState.database.markEpisodeWatched(
                        mediaId: mediaIdentifier,
                        episodeId: selectedEpisode.id,
                        title: selectedEpisode.displayTitle
                    )
                }
            } else if priorState.isWatched {
                try await appState.database.markMovieUnwatched(mediaId: mediaIdentifier)
            } else {
                try await appState.database.markMovieWatched(
                    mediaId: mediaIdentifier,
                    title: mediaItem.title
                )
            }

            await refreshWatchHistoryState()
            mediaLibrary.statusMessage = priorState.isWatched ? "Marked as not watched." : "Marked as watched."
            NotificationCenter.default.post(name: .watchHistoryDidChange, object: nil)
        } catch {
            handleLibraryError(error, fallbackPrefix: "Watch state update failed")
        }
    }

    func makePlayerSessionRequest(
        stream: StreamInfo,
        preview: MediaPreview,
        availableStreams: [StreamInfo]? = nil
    ) -> PlayerSessionRequest {
        let title = mediaItem?.title ?? preview.title
        let mediaIdentifier = DetailMediaIdentityPolicy.canonicalMediaID(
            mediaItem: mediaItem,
            preview: preview
        ) ?? preview.id
        let tmdbId = mediaItem?.tmdbId ?? preview.tmdbId
        let activeEpisodeId = (mediaItem?.type == .series ? selectedEpisode?.id : nil)
        let nextEpisode = nextEpisodeCandidate()
        let streamPool = PlayerSessionRouting.sessionStreams(
            primary: stream,
            available: availableStreams ?? debridResolver.streams
        )

        return PlayerSessionRequest(
            stream: stream,
            availableStreams: streamPool,
            mediaTitle: title,
            mediaId: mediaIdentifier,
            imdbId: DetailMediaIdentityPolicy.imdbID(mediaItem: mediaItem, preview: preview),
            tmdbId: tmdbId,
            posterPath: mediaItem?.posterPath ?? preview.posterPath,
            backdropPath: mediaItem?.backdropPath ?? preview.backdropPath,
            episodeId: activeEpisodeId,
            nextEpisode: nextEpisode
        )
    }

    private func nextEpisodeCandidate() -> PlayerSessionRequest.NextEpisodeCandidate? {
        guard mediaItem?.type == .series, let selectedEpisode else { return nil }
        return DetailNextEpisodePolicy.nextCandidate(
            selectedEpisode: selectedEpisode,
            currentEpisodes: episodes,
            nextSeasonFirstEpisode: nextSeasonFirstEpisode
        )
    }

    private func attachRecoveryContext(
        to stream: StreamInfo,
        torrent: TorrentResult,
        preferredService: DebridServiceType?,
        seasonNumber: Int?,
        episodeNumber: Int?
    ) -> StreamInfo {
        let actualService = DebridServiceType(rawValue: stream.debridService) ?? preferredService
        let recoveryContext = StreamRecoveryContext(
            infoHash: torrent.infoHash,
            preferredService: actualService,
            magnetURI: torrent.magnetURI,
            seasonNumber: seasonNumber,
            episodeNumber: episodeNumber
        )
        return stream.withRecoveryContext(recoveryContext)
    }

    private func attachDirectStreamRecoveryContextIfPossible(
        to stream: StreamInfo,
        torrent: TorrentResult,
        preferredService: DebridServiceType?,
        seasonNumber: Int?,
        episodeNumber: Int?
    ) -> StreamInfo {
        let magnetHash = JSONValueParsing.extractInfoHash(from: torrent.magnetURI)
            .flatMap(DebridHashValidator.normalizedInfoHash)
        let recoveryHash = DebridHashValidator.normalizedInfoHash(torrent.infoHash)
            ?? magnetHash
        guard let recoveryHash else {
            return stream
        }

        guard let recoveryContext = StreamRecoveryContext(
            infoHash: recoveryHash,
            preferredService: preferredService,
            magnetURI: torrent.magnetURI,
            seasonNumber: seasonNumber,
            episodeNumber: episodeNumber
        ) else {
            return stream
        }

        return stream.withRecoveryContext(recoveryContext)
    }

    private func fetchAllEpisodesForSeries() async throws -> [Episode] {
        guard let mediaItem, mediaItem.type == .series else { return [] }

        let loadedBySeason = Dictionary(grouping: episodes, by: \.seasonNumber)
        guard !seasons.isEmpty else {
            return deduplicatedEpisodes(Array(loadedBySeason.values.joined()))
        }

        let service = metadataProviderFactory(currentMetadataAPIKey)
        let lookupID = DetailMetadataLookupPolicy.episodeLookupID(
            for: mediaItem,
            preference: service.detailLookupPreference
        )
        var allEpisodes: [Episode] = []

        for season in seasons.sorted(by: { $0.seasonNumber < $1.seasonNumber }) {
            if let loadedSeasonEpisodes = loadedBySeason[season.seasonNumber],
               !loadedSeasonEpisodes.isEmpty,
               loadedSeasonEpisodes.count >= season.episodeCount {
                allEpisodes.append(contentsOf: loadedSeasonEpisodes)
                continue
            }

            let seasonEpisodes = try await service.getEpisodes(id: lookupID, type: mediaItem.type, season: season.seasonNumber)
            allEpisodes.append(contentsOf: seasonEpisodes)
        }

        return deduplicatedEpisodes(allEpisodes)
    }

    private func deduplicatedEpisodes(_ episodes: [Episode]) -> [Episode] {
        var seenEpisodeIDs: Set<String> = []
        return episodes.filter { episode in
            seenEpisodeIDs.insert(episode.id).inserted
        }
    }

    private func toggleLibraryMembership(for listType: UserLibraryEntry.ListType) async {
        let mediaIdentifier = currentMediaIdentifier
        guard let mediaIdentifier else {
            mediaLibrary.statusMessage = "Library update failed: missing media identifier."
            return
        }

        beginLoading(.librarySync)
        defer { finishLoadingIfNeeded(for: .librarySync) }

        do {
            let alreadyInList = try await appState.database.isInLibrary(mediaId: mediaIdentifier, listType: listType)
            if alreadyInList {
                try await appState.database.removeFromLibrary(mediaId: mediaIdentifier, listType: listType)
                mediaLibrary.statusMessage = "Removed from \(listType.displayName.lowercased())."
            } else {
                let rootFolderID = try await appState.database.fetchSystemLibraryFolderID(listType: listType)
                let entry = UserLibraryEntry(
                    id: "\(mediaIdentifier)-\(listType.rawValue)",
                    mediaId: mediaIdentifier,
                    folderId: rootFolderID,
                    listType: listType,
                    addedAt: Date()
                )
                try await appState.database.addToLibrary(entry)
                mediaLibrary.statusMessage = "Added to \(listType.displayName.lowercased())."
            }

            await refreshLibraryState()
            NotificationCenter.default.post(name: .libraryDidChange, object: nil)
        } catch {
            handleLibraryError(error, fallbackPrefix: "Library update failed")
        }
    }

    private func refreshLibraryState() async {
        guard let mediaIdentifier = currentMediaIdentifier else { return }

        async let watchlistMembership = appState.database.isInLibrary(mediaId: mediaIdentifier, listType: .watchlist)
        async let favoritesMembership = appState.database.isInLibrary(mediaId: mediaIdentifier, listType: .favorites)
        async let watchlistFolders = appState.database.fetchAllLibraryFolders(listType: .watchlist)
        async let favoriteFolders = appState.database.fetchAllLibraryFolders(listType: .favorites)

        mediaLibrary.isInWatchlist = (try? await watchlistMembership) ?? false
        mediaLibrary.isInFavorites = (try? await favoritesMembership) ?? false
        mediaLibrary.watchlistFolders = sortedFolders((try? await watchlistFolders) ?? [])
        mediaLibrary.favoriteFolders = sortedFolders((try? await favoriteFolders) ?? [])
    }

    private func refreshWatchHistoryState() async {
        guard let mediaIdentifier = currentMediaIdentifier else {
            mediaLibrary.watchHistory = nil
            episodeWatchStates = [:]
            return
        }

        mediaLibrary.watchHistory = try? await appState.database.fetchWatchHistory(mediaId: mediaIdentifier)

        let mediaType = mediaItem?.type ?? previewContext?.type
        if mediaType == .series {
            let freshStates = (try? await appState.database.fetchEpisodeWatchStates(mediaId: mediaIdentifier)) ?? [:]
            // Only reassign if data actually changed to prevent cascading re-renders
            if freshStates != episodeWatchStates {
                episodeWatchStates = freshStates
            }
        } else {
            if !episodeWatchStates.isEmpty {
                episodeWatchStates = [:]
            }
        }
    }

    private func refreshFeedbackState() async {
        let selectedScale = (try? await appState.settingsManager.getFeedbackScaleMode()) ?? .likeDislike
        feedbackScaleMode = selectedScale.canonicalMode

        guard let mediaIdentifier = currentMediaIdentifier else {
            currentFeedbackValue = nil
            return
        }

        guard let latestRating = try? await appState.database.fetchLatestTasteRating(mediaId: mediaIdentifier),
              let eventValue = latestRating.feedbackValue else {
            currentFeedbackValue = nil
            return
        }

        let sourceScale = latestRating.feedbackScale?.canonicalMode ?? feedbackScaleMode
        let normalized = sourceScale.normalizedValue(eventValue)
        currentFeedbackValue = feedbackScaleMode.value(fromNormalized: normalized)
    }

    private func sortedFolders(_ folders: [LibraryFolder]) -> [LibraryFolder] {
        folders.sorted { lhs, rhs in
            if lhs.isSystem != rhs.isSystem {
                return lhs.isSystem
            }
            return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
        }
    }

    private func resolvedFolderName(for listType: UserLibraryEntry.ListType, folderId: String) -> String {
        let folders: [LibraryFolder]
        switch listType {
        case .watchlist:
            folders = mediaLibrary.watchlistFolders
        case .favorites:
            folders = mediaLibrary.favoriteFolders
        case .history:
            folders = []
        }
        return folders.first(where: { $0.id == folderId })?.name ?? listType.displayName
    }

    private func handleLibraryError(_ error: Error, fallbackPrefix: String) {
        let appError = AppError(error, fallback: .unknown("\(fallbackPrefix): \(error.localizedDescription)"))
        mediaLibrary.statusMessage = appError.errorDescription
        viewState = .error(appError)
    }

    private func buildQuery(for item: MediaItem, season: Int?, episode: Int?) -> String {
        var query = item.title
        if item.type == .series, let season, let episode {
            query += " S\(String(format: "%02d", season))E\(String(format: "%02d", episode))"
        } else if let year = item.year {
            query += " \(year)"
        }
        return query
    }

    private func invalidateSearchResultsForEpisodeChange() {
        torrentSearch.invalidateForEpisodeChange()
        debridResolver.clearStreams()
        lastFailedTorrent = nil
        clearError()
    }

    private func setError(_ error: Error, fallback: AppError) {
        lastFailedPhase = loadingPhase
        viewState = .error(AppError(error, fallback: fallback))
    }

    func searchContextKey(mediaID: String, season: Int?, episode: Int?) -> String {
        guard mediaItem?.type == .series else {
            return mediaID
        }
        let seasonPart = season.map(String.init) ?? "0"
        let episodePart = episode.map(String.init) ?? "0"
        return "\(mediaID)-s\(seasonPart)e\(episodePart)"
    }

    private func sortTorrentsByPreferences(_ torrents: [TorrentResult]) async -> [TorrentResult] {
        let preferredQuality = (try? await appState.settingsManager.getPreferredQuality()) ?? .hd1080p
        let preferCached = (try? await appState.settingsManager.getBool(key: SettingsKeys.preferCachedStreams, default: true)) ?? true
        let preferAtmos = (try? await appState.settingsManager.getBool(key: SettingsKeys.preferAtmosAudio, default: true)) ?? true
        let hdrRaw = (try? await appState.settingsManager.getString(key: SettingsKeys.preferredHDRFormat)) ?? HDRPreference.auto.rawValue
        let hdrPreference = HDRPreference(rawValue: hdrRaw) ?? .auto

        return await TorrentRanking.sortConcurrently(
            torrents,
            preferredQuality: preferredQuality,
            preferCached: preferCached,
            preferAtmos: preferAtmos,
            hdrPreference: hdrPreference
        )
    }

    private func sourceFilterOptionsFromSettings() async -> SourceFilterOptions {
        SourceFilterOptions.fromStoredValues(
            presetRawValue: try? await appState.settingsManager.getString(key: SettingsKeys.sourceFilterPreset),
            hideConfirmedDownloads: try? await appState.settingsManager.getBool(
                key: SettingsKeys.sourceFilterHideDownloads,
                default: false
            ),
            hideCamSources: try? await appState.settingsManager.getBool(
                key: SettingsKeys.sourceFilterHideCam,
                default: true
            ),
            minimumSeedersRawValue: try? await appState.settingsManager.getString(key: SettingsKeys.sourceFilterMinimumSeeders),
            maximumSizeGBRawValue: try? await appState.settingsManager.getString(key: SettingsKeys.sourceFilterMaximumSizeGB),
            minimumQualityRawValue: try? await appState.settingsManager.getString(key: SettingsKeys.sourceFilterMinimumQuality)
        )
    }

    func isLoading(_ phase: LoadingPhase) -> Bool {
        loadingPhase == phase
    }

    private func beginLoading(_ phase: LoadingPhase) {
        lastFailedPhase = nil
        viewState = .loading(phase)
    }

    private func markLoaded() {
        lastFailedPhase = nil
        viewState = .loaded
    }

    private func finishLoadingIfNeeded(for phase: LoadingPhase) {
        guard case .loading(let activePhase) = viewState, activePhase == phase else { return }
        lastFailedPhase = nil
        viewState = .loaded
    }

    private func clearError() {
        if case .error = viewState {
            viewState = .idle
        }
    }

    private func nextDetailLoadGeneration() -> Int {
        detailLoadGeneration &+= 1
        return detailLoadGeneration
    }

    private func nextSeasonLoadGeneration() -> Int {
        seasonLoadGeneration &+= 1
        return seasonLoadGeneration
    }

    private func isCurrentDetailLoad(_ generation: Int) -> Bool {
        detailLoadGeneration == generation
    }

    private func isCurrentSeasonLoad(_ generation: Int, seasonNumber: Int) -> Bool {
        seasonLoadGeneration == generation && selectedSeason == seasonNumber
    }
}
