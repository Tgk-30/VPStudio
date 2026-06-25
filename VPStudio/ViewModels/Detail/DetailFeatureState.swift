import Foundation
import Observation

enum LoadingPhase: String, Sendable, Equatable {
    case detail
    case seasonEpisodes
    case torrentSearch
    case streamResolution
    case downloadQueue
    case librarySync
}

enum ViewState: Sendable, Equatable {
    case idle
    case loading(LoadingPhase)
    case loaded
    case error(AppError)
}

@Observable
@MainActor
final class TorrentSearchState {
    private var rawResults: [TorrentResult] = []
    private var allResults: [TorrentResult] = []
    private var visibleResults: [TorrentResult] = []
    private var sourceFilterOptions: SourceFilterOptions = .default

    // `results` remains writable for compatibility with older call-sites/tests.
    // Direct assignment intentionally publishes all provided results at once.
    var results: [TorrentResult] {
        get { visibleResults }
        set {
            rawResults = newValue
            allResults = SourceFilterPolicy.filtered(newValue, options: sourceFilterOptions)
            visibleResults = allResults
        }
    }

    var allHashes: [String] {
        rawResults.compactMap { $0.requiresDebridResolution ? $0.infoHash : nil }
    }

    /// The full ranked result set including those beyond the visible batch. Used
    /// for best-cached selection so a confirmed-cached source ranked outside the
    /// initial visible window is still eligible for one-tap play.
    var allResultsSnapshot: [TorrentResult] { allResults }
    var remainingResultCount: Int { max(allResults.count - visibleResults.count, 0) }
    var canLoadMoreResults: Bool { remainingResultCount > 0 }

    var didSearch = false
    var lastSearchEpisodeId: String?
    var lastSearchContextKey: String?

    func setSourceFilterOptions(_ options: SourceFilterOptions) {
        sourceFilterOptions = options
        reapplySourceFilter(preservingVisibleCount: visibleResults.count)
    }

    func setSearchResults(_ newResults: [TorrentResult], initialBatchSize: Int) {
        rawResults = newResults
        allResults = SourceFilterPolicy.filtered(newResults, options: sourceFilterOptions)
        visibleResults = Array(allResults.prefix(max(0, initialBatchSize)))
    }

    @discardableResult
    func revealMoreResults(batchSize: Int) -> Bool {
        guard batchSize > 0 else { return false }
        guard canLoadMoreResults else { return false }

        let nextVisibleCount = min(allResults.count, visibleResults.count + batchSize)
        guard nextVisibleCount > visibleResults.count else { return false }

        visibleResults = Array(allResults.prefix(nextVisibleCount))
        return true
    }

    func updateCacheStatus(_ cacheResults: [String: (CacheStatus, DebridServiceType)]) {
        guard !cacheResults.isEmpty else { return }
        let visibleCount = visibleResults.count
        var resultsChanged = false
        for i in rawResults.indices {
            let hash = rawResults[i].infoHash
            guard let (status, serviceType) = cacheResults[hash] else { continue }

            switch status {
            case .cached:
                // Only the cached transition records the resolving service.
                guard rawResults[i].cacheAvailability != .cached else { continue }
                rawResults[i].cacheAvailability = .cached
                rawResults[i].cachedOnService = serviceType.rawValue
                resultsChanged = true
            case .notCached:
                // Confirmed-uncached: distinguish must-download from not-yet-checked.
                // Never downgrade a previously-confirmed cached hit.
                guard rawResults[i].cacheAvailability == .unknown else { continue }
                rawResults[i].cacheAvailability = .notCached
                resultsChanged = true
            case .unknown:
                continue
            }
        }
        guard resultsChanged else { return }
        reapplySourceFilter(preservingVisibleCount: visibleCount)
    }

    func markCompletedSearch(episodeId: String?, contextKey: String) {
        didSearch = true
        lastSearchEpisodeId = episodeId
        lastSearchContextKey = contextKey
    }

    func invalidateForEpisodeChange() {
        rawResults = []
        allResults = []
        visibleResults = []
    }

    private func reapplySourceFilter(preservingVisibleCount visibleCount: Int) {
        allResults = SourceFilterPolicy.filtered(rawResults, options: sourceFilterOptions)
        visibleResults = Array(allResults.prefix(max(0, visibleCount)))
    }
}

@Observable
@MainActor
final class DebridResolverState {
    var streams: [StreamInfo] = []

    func appendStreamIfNeeded(_ stream: StreamInfo) {
        guard !streams.contains(where: { $0.id == stream.id }) else { return }
        streams.append(stream)
    }

    func clearStreams() {
        streams = []
    }
}

enum DownloadButtonState: Sendable, Equatable {
    case idle
    case resolving
    case downloading
    case completed
    case failed
}

@Observable
@MainActor
final class MediaLibraryState {
    var watchHistory: WatchHistory?
    var isInWatchlist = false
    var isInFavorites = false
    var watchlistFolders: [LibraryFolder] = []
    var favoriteFolders: [LibraryFolder] = []
    var statusMessage: String?
}
