import Combine
import SwiftUI

enum DetailInitialAction: String, Hashable, Sendable {
    case none
    case resumePlayback
    /// One-tap play from a recommendation: on open, search sources and play the
    /// best *confirmed-cached* result. If none is cached (cache enrichment is
    /// async), this lands on Detail best-effort rather than force-playing an
    /// uncached source. See `DetailPlaybackSelectionPolicy.bestCachedResult`.
    case playBestCached
}

enum DetailAutoSearchPolicy {
    static func shouldAutoSearch(
        previewType: MediaType,
        hasMediaItem: Bool,
        hasSelectedEpisode: Bool,
        hasExplicitEpisodeContext: Bool
    ) -> Bool {
        guard hasMediaItem else { return false }
        if previewType == .movie {
            return true
        }

        // Series detail can hydrate a lot of late-arriving content on first open
        // (episode context, stream results, cache enrichment). Requiring an
        // explicit follow-up action keeps the initial scroll container stable.
        let _ = hasSelectedEpisode
        let _ = hasExplicitEpisodeContext
        return false
    }
}

enum DetailInitialRenderPolicy {
    static func shouldShowContent(
        hasViewModel: Bool,
        isPreparingInitialPresentation: Bool,
        hasResolvedPrimaryMedia: Bool = false
    ) -> Bool {
        hasViewModel && (!isPreparingInitialPresentation || hasResolvedPrimaryMedia)
    }
}

enum DetailInitialActionPolicy {
    enum ResumePlaybackOutcome: Equatable {
        case ignore
        case deferUntilMediaLoads
        case missingEpisode
        case activeSession
        case searchAndPlay
        /// Search sources then play the best confirmed-cached result; landing on
        /// Detail (no force-play) when none is cached.
        case searchAndPlayBestCached
    }

    /// Both `.resumePlayback` and `.playBestCached` are "play on open" actions
    /// that share the same gating (defer until media loads, surface an active
    /// session, require a selected episode for series). They differ only in
    /// which source is chosen at the final play step.
    static func isPlayOnOpen(_ action: DetailInitialAction) -> Bool {
        action == .resumePlayback || action == .playBestCached
    }

    static func shouldDeferUntilMediaLoads(
        action: DetailInitialAction,
        hasMediaItem: Bool
    ) -> Bool {
        isPlayOnOpen(action) && !hasMediaItem
    }

    static func shouldAttemptResumePlayback(
        action: DetailInitialAction,
        hasMediaItem: Bool
    ) -> Bool {
        isPlayOnOpen(action) && hasMediaItem
    }

    static func resumePlaybackOutcome(
        action: DetailInitialAction,
        hasMediaItem: Bool,
        previewType: MediaType,
        hasSelectedEpisode: Bool,
        hasActivePlayerSession: Bool
    ) -> ResumePlaybackOutcome {
        if shouldDeferUntilMediaLoads(action: action, hasMediaItem: hasMediaItem) {
            return .deferUntilMediaLoads
        }

        guard shouldAttemptResumePlayback(action: action, hasMediaItem: hasMediaItem) else {
            return .ignore
        }

        if hasActivePlayerSession {
            return .activeSession
        }

        if previewType == .series, !hasSelectedEpisode {
            return .missingEpisode
        }

        return action == .playBestCached ? .searchAndPlayBestCached : .searchAndPlay
    }
}

enum DetailInitialActionHandlingPolicy {
    enum Handling: Equatable {
        case deferUntilMediaLoads
        case ignore
        case showMissingEpisodeError
        case showActiveSessionToast
        case beginPlayback
        /// Search sources then play the best confirmed-cached result; best-effort
        /// (land on Detail when none is cached).
        case beginBestCachedPlayback
    }

    static func handling(for outcome: DetailInitialActionPolicy.ResumePlaybackOutcome) -> Handling {
        switch outcome {
        case .deferUntilMediaLoads:
            return .deferUntilMediaLoads
        case .ignore:
            return .ignore
        case .missingEpisode:
            return .showMissingEpisodeError
        case .activeSession:
            return .showActiveSessionToast
        case .searchAndPlay:
            return .beginPlayback
        case .searchAndPlayBestCached:
            return .beginBestCachedPlayback
        }
    }
}

enum DetailRefreshLoadingPresentationPolicy {
    static let refreshTitle = "Refreshing Details"

    static func shouldShowBlockingOverlay(
        isLoadingDetail: Bool,
        isLoadingSeasonEpisodes: Bool,
        hasMediaItem: Bool
    ) -> Bool {
        let _ = isLoadingSeasonEpisodes
        return isLoadingDetail && !hasMediaItem
    }

    static func shouldShowRefreshIndicator(
        isLoadingDetail: Bool,
        isLoadingSeasonEpisodes: Bool,
        hasMediaItem: Bool
    ) -> Bool {
        isLoadingDetail && hasMediaItem && !isLoadingSeasonEpisodes
    }

    static func blockingOverlayTitle(isLoadingSeasonEpisodes: Bool) -> String {
        isLoadingSeasonEpisodes ? "Loading Episodes" : "Loading Details"
    }
}

enum DetailPresentationPolicy {
    static let activeSessionToastText = "A video is already playing"

    static func yearText(_ year: Int?) -> String? {
        year.map(String.init)
    }

    static func imdbRatingText(_ rating: Double?) -> String? {
        guard let rating, rating > 0 else { return nil }
        return String(format: "%.1f", rating)
    }

    static func runtimeText(_ runtimeString: String?) -> String? {
        guard let runtimeString, !runtimeString.isEmpty else { return nil }
        return runtimeString
    }

    static func feedbackDraftValue(currentValue: Double?, scaleMode: FeedbackScaleMode) -> Double {
        if let currentValue {
            return scaleMode.clamp(currentValue)
        }
        return scaleMode.maximumValue
    }

    static func shareItem(
        previewID: String,
        previewTitle: String,
        previewType: MediaType,
        previewTMDBID: Int?,
        mediaTitle: String?,
        mediaID: String? = nil,
        mediaTMDBID: Int?
    ) -> String {
        let baseTitle = mediaTitle ?? previewTitle
        if let imdbID = mediaID.flatMap(imdbID(from:)) ?? imdbID(from: previewID) {
            return "\(baseTitle)\nhttps://www.imdb.com/title/\(imdbID)/"
        }
        return baseTitle
    }

    private static func imdbID(from id: String) -> String? {
        IMDbIdentifierPolicy.firstID(in: id)
    }
}

enum DetailPlaybackCopyPolicy {
    enum PlaybackAction: Equatable {
        case cast
        case playTorrent
        case resumePlayback
    }

    static let missingEpisodeMessage = "Pick an episode to continue watching."

    static func noStreamsMessage(for action: PlaybackAction) -> String {
        switch action {
        case .cast:
            return "No streams available to cast right now."
        case .playTorrent:
            return "Could not open stream. Please try another result."
        case .resumePlayback:
            return "No streams are available to resume right now."
        }
    }

    static func streamResolutionFailedMessage(for action: PlaybackAction) -> String {
        switch action {
        case .cast:
            return "Could not open stream for casting."
        case .playTorrent:
            return "Could not open stream. Please try another result."
        case .resumePlayback:
            return "Could not resume playback right now."
        }
    }
}

enum DetailQASamplePolicy {
    struct DownloadArguments: Equatable, Sendable {
        let mediaId: String
        let episodeId: String?
        let mediaTitle: String
        let mediaType: String
        let posterPath: String?
        let seasonNumber: Int?
        let episodeNumber: Int?
        let episodeTitle: String?
    }

    static func previewTaskIdentity(
        preview: MediaPreview,
        initialAction: DetailInitialAction
    ) -> String {
        [
            preview.type.rawValue,
            preview.id,
            preview.tmdbId.map(String.init) ?? "none",
            preview.episodeId ?? "none",
            preview.seasonNumber.map(String.init) ?? "none",
            preview.episodeNumber.map(String.init) ?? "none",
            initialAction.rawValue
        ].joined(separator: "-")
    }

    static func sampleFileName(
        mediaTitle: String,
        previewType: MediaType,
        selectedEpisode: Episode?
    ) -> String {
        if previewType == .series, let selectedEpisode {
            return "\(mediaTitle)-S\(String(format: "%02d", selectedEpisode.seasonNumber))E\(String(format: "%02d", selectedEpisode.episodeNumber)).mp4"
        }
        return "\(mediaTitle).mp4"
    }

    static func makeSampleStreams(
        sampleURLs: [URL],
        mediaTitle: String,
        previewType: MediaType,
        selectedEpisode: Episode?
    ) -> [StreamInfo]? {
        guard !sampleURLs.isEmpty else { return nil }
        let fileName = sampleFileName(
            mediaTitle: mediaTitle,
            previewType: previewType,
            selectedEpisode: selectedEpisode
        )

        return sampleURLs.map { sampleURL in
            StreamInfo(
                streamURL: sampleURL,
                quality: .hd720p,
                codec: .h264,
                audio: .aac,
                source: .webDL,
                hdr: .sdr,
                fileName: fileName,
                sizeBytes: nil,
                debridService: "qa-sample"
            )
        }
    }

    static func downloadArguments(
        mediaItem: MediaItem?,
        preview: MediaPreview? = nil,
        previewType: MediaType,
        selectedEpisode: Episode?
    ) -> DownloadArguments? {
        guard let mediaItem else { return nil }
        let isSeries = previewType == .series
        return DownloadArguments(
            mediaId: DetailMediaIdentityPolicy.canonicalMediaID(mediaItem: mediaItem, preview: preview) ?? mediaItem.id,
            episodeId: isSeries ? selectedEpisode?.id : nil,
            mediaTitle: mediaItem.title,
            mediaType: mediaItem.type.rawValue,
            posterPath: mediaItem.posterPath,
            seasonNumber: isSeries ? selectedEpisode?.seasonNumber : nil,
            episodeNumber: isSeries ? selectedEpisode?.episodeNumber : nil,
            episodeTitle: isSeries ? selectedEpisode?.title : nil
        )
    }
}

enum DetailQAActionsPolicy {
    enum LibraryMutation: Equatable {
        case addWatchlist
        case addFavorites
        case removeWatchlist
        case removeFavorites
    }

    static func shouldRun(
        isQAEnabled: Bool,
        didRunQAActions: Bool,
        hasMediaItem: Bool
    ) -> Bool {
        isQAEnabled && !didRunQAActions && hasMediaItem
    }

    static func seasonToLoad(
        previewType: MediaType,
        selectedSeason: Int?,
        currentSeason: Int
    ) -> Int? {
        guard previewType == .series else { return nil }
        guard let selectedSeason, selectedSeason != currentSeason else { return nil }
        return selectedSeason
    }

    static func selectedEpisodeNumber(
        previewType: MediaType,
        selectedEpisode: Int?
    ) -> Int? {
        guard previewType == .series else { return nil }
        return selectedEpisode
    }

    static func episodeToSelect(
        previewType: MediaType,
        selectedEpisode: Int?,
        episodes: [Episode]
    ) -> Episode? {
        guard let episodeNumber = selectedEpisodeNumber(
            previewType: previewType,
            selectedEpisode: selectedEpisode
        ) else {
            return nil
        }
        return episodes.first(where: { $0.episodeNumber == episodeNumber })
    }

    static func libraryMutations(
        autoAddWatchlist: Bool,
        autoAddFavorites: Bool,
        autoRemoveWatchlist: Bool,
        autoRemoveFavorites: Bool,
        isInWatchlist: Bool,
        isInFavorites: Bool
    ) -> [LibraryMutation] {
        var mutations: [LibraryMutation] = []

        if autoAddWatchlist, !isInWatchlist {
            mutations.append(.addWatchlist)
        }
        if autoAddFavorites, !isInFavorites {
            mutations.append(.addFavorites)
        }
        if autoRemoveWatchlist, isInWatchlist {
            mutations.append(.removeWatchlist)
        }
        if autoRemoveFavorites, isInFavorites {
            mutations.append(.removeFavorites)
        }

        return mutations
    }
}

enum DetailPlayerHandoffPolicy {
    enum Route: Equatable {
        case showActiveSessionToast
        case launchedExternally
        case openInternalPlayerWindow
    }

    static func route(
        hasActivePlayerSession: Bool,
        didLaunchPreferredExternalPlayer: Bool
    ) -> Route {
        if hasActivePlayerSession {
            return .showActiveSessionToast
        }
        if didLaunchPreferredExternalPlayer {
            return .launchedExternally
        }
        return .openInternalPlayerWindow
    }
}

struct DetailView: View {
    let preview: MediaPreview
    let initialAction: DetailInitialAction
    @Environment(AppState.self) private var appState
    @Environment(\.openWindow) private var openWindow
    @Environment(\.openURL) private var openURL
    @State private var viewModel: DetailViewModel?
    @State private var metadataApiKey = ""
    @State private var isShowingRatingSheet = false
    @State private var draftFeedbackValue: Double = 1
    @State private var metadataReloadTask: Task<Void, Never>?
    @State private var libraryReloadTask: Task<Void, Never>?
    @State private var feedbackReloadTask: Task<Void, Never>?
    @State private var downloadsReloadTask: Task<Void, Never>?
    @State private var torrentAutoSearchTask: Task<Void, Never>?
    @State private var streamResolutionTask: Task<Void, Never>?
    @State private var showActiveSessionToast = false
    @State private var activeSessionToastTask: Task<Void, Never>?
    @State private var didRunQAActions = false
    /// True from the moment a play button is clicked until the player window has taken over.
    /// Used to disable all play buttons and prevent double-taps during player launch.
    @State private var isPlayerOpening = false
    /// Error message to show when player fails to open.
    @State private var playerOpeningError: String?
    /// Identifies which torrent row triggered the in-progress (or failed) play, so the inline
    /// "Opening player…"/error feedback is scoped to that one row instead of broadcasting to
    /// every row. `nil` for non-row plays (cast, resume) whose feedback lives on the primary
    /// button / screen alert rather than a row.
    @State private var openingTorrentID: TorrentResult.ID?
    @State private var isPreparingInitialPresentation = true
    @State private var hasHandledInitialAction = false
    private let streamResultsAnchor = "detail-stream-results-anchor"
    private let disablesAutomaticLoading: Bool

    init(
        preview: MediaPreview,
        initialAction: DetailInitialAction = .none,
        initialViewModel: DetailViewModel? = nil,
        initialOMDbApiKey: String = "",
        initialIsShowingRatingSheet: Bool = false,
        initialDraftFeedbackValue: Double = 1,
        initialShowActiveSessionToast: Bool = false,
        initialIsPlayerOpening: Bool = false,
        initialPlayerOpeningError: String? = nil,
        initialIsPreparingInitialPresentation: Bool? = nil,
        disablesAutomaticLoading: Bool = false
    ) {
        self.preview = preview
        self.initialAction = initialAction
        self.disablesAutomaticLoading = disablesAutomaticLoading
        _viewModel = State(initialValue: initialViewModel)
        _metadataApiKey = State(initialValue: initialOMDbApiKey)
        _isShowingRatingSheet = State(initialValue: initialIsShowingRatingSheet)
        _draftFeedbackValue = State(initialValue: initialDraftFeedbackValue)
        _showActiveSessionToast = State(initialValue: initialShowActiveSessionToast)
        _isPlayerOpening = State(initialValue: initialIsPlayerOpening)
        _playerOpeningError = State(initialValue: initialPlayerOpeningError)
        _isPreparingInitialPresentation = State(
            initialValue: initialIsPreparingInitialPresentation ?? (initialViewModel == nil)
        )
    }

    private var shouldShowDetailContent: Bool {
        return DetailInitialRenderPolicy.shouldShowContent(
            hasViewModel: viewModel != nil,
            isPreparingInitialPresentation: isPreparingInitialPresentation,
            hasResolvedPrimaryMedia: viewModel?.mediaItem != nil
        )
    }

    var body: some View {
        Group {
            if let vm = viewModel, shouldShowDetailContent {
                detailContent(vm)
                    .transition(.opacity)
            } else {
                DetailSkeletonView()
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.35), value: shouldShowDetailContent)
        // Surface play-open failures that have no torrent row to render them (missing episode,
        // or a no-streams/resolution failure when results are empty) — otherwise the user taps
        // Play and nothing visibly happens. Gated on no rows so it never double-shows with the
        // per-row error renderer in DetailTorrentsSection.
        .alert(
            "Can’t Play",
            isPresented: Binding(
                get: { playerOpeningError != nil && (viewModel?.torrentSearch.results.isEmpty ?? true) },
                set: { presented in if !presented { playerOpeningError = nil } }
            ),
            presenting: playerOpeningError
        ) { _ in
            Button("OK", role: .cancel) { playerOpeningError = nil }
        } message: { message in
            Text(message)
        }
        .task(id: previewTaskIdentity) {
            guard !disablesAutomaticLoading else { return }
            isPreparingInitialPresentation = true
            didRunQAActions = false
            hasHandledInitialAction = false
            torrentAutoSearchTask?.cancel()
            torrentAutoSearchTask = nil
            await reloadDetailForLatestMetadataKey()
            guard !Task.isCancelled else { return }
            isPreparingInitialPresentation = false
        }
        .onDisappear {
            viewModel?.cancelInFlightWork()
            metadataReloadTask?.cancel()
            metadataReloadTask = nil
            libraryReloadTask?.cancel()
            libraryReloadTask = nil
            feedbackReloadTask?.cancel()
            feedbackReloadTask = nil
            downloadsReloadTask?.cancel()
            downloadsReloadTask = nil
            torrentAutoSearchTask?.cancel()
            torrentAutoSearchTask = nil
            streamResolutionTask?.cancel()
            streamResolutionTask = nil
            activeSessionToastTask?.cancel()
            activeSessionToastTask = nil
        }
        .onReceive(NotificationCenter.default.publisher(for: .metadataApiKeyDidChange)) { _ in
            metadataReloadTask?.cancel()
            metadataReloadTask = Task { await reloadDetailForLatestMetadataKey() }
        }
        .onReceive(NotificationCenter.default.publisher(for: .libraryDidChange)) { _ in
            guard let vm = viewModel else { return }
            libraryReloadTask?.cancel()
            libraryReloadTask = Task { await vm.reloadLibraryState() }
        }
        .onReceive(NotificationCenter.default.publisher(for: .watchHistoryDidChange)) { _ in
            guard let vm = viewModel else { return }
            libraryReloadTask?.cancel()
            libraryReloadTask = Task { await vm.reloadLibraryState() }
        }
        .onReceive(NotificationCenter.default.publisher(for: .tasteProfileDidChange)) { _ in
            guard let vm = viewModel else { return }
            feedbackReloadTask?.cancel()
            feedbackReloadTask = Task { await vm.reloadFeedbackState() }
        }
        .onReceive(NotificationCenter.default.publisher(for: .downloadsDidChange)) { _ in
            guard let vm = viewModel else { return }
            downloadsReloadTask?.cancel()
            downloadsReloadTask = Task { await vm.refreshDownloadStates() }
        }
        .sheet(isPresented: $isShowingRatingSheet) {
            if let vm = viewModel {
                DetailRatingSheet(
                    viewModel: vm,
                    isShowing: $isShowingRatingSheet,
                    draftFeedbackValue: $draftFeedbackValue
                )
            }
        }
    }

    @MainActor
    private func reloadDetailForLatestMetadataKey() async {
        torrentAutoSearchTask?.cancel()
        torrentAutoSearchTask = nil

        let key = (try? await appState.settingsManager.getMetadataApiKey()) ?? ""
        metadataApiKey = key

        let vm: DetailViewModel
        if let existingViewModel = viewModel {
            vm = existingViewModel
        } else {
            let created = DetailViewModel(appState: appState)
            viewModel = created
            vm = created
        }

        vm.setPreviewContext(preview)
        await vm.loadDetail(preview: preview, apiKey: key)

        // Auto-search streams once metadata loads for movies only, but do not
        // keep first content render blocked behind indexer/network work.
        let shouldAutoSearchTorrents = initialAction == .none && !QARuntimeOptions.isEnabled && DetailAutoSearchPolicy.shouldAutoSearch(
            previewType: preview.type,
            hasMediaItem: vm.mediaItem != nil,
            hasSelectedEpisode: vm.selectedEpisode != nil,
            hasExplicitEpisodeContext: preview.episodeId != nil || preview.episodeNumber != nil
        )

        if !QARuntimeOptions.isEnabled {
            await runInitialActionIfNeeded(vm)
        }

        await runQAActionsIfNeeded(vm)

        if shouldAutoSearchTorrents {
            scheduleAutoTorrentSearch(vm)
        }
    }

    @ViewBuilder
    private func detailContent(_ vm: DetailViewModel) -> some View {
        SeriesDetailLayout(
            viewModel: vm,
            title: preview.title,
            metadataApiKey: metadataApiKey,
            mediaType: preview.type,
            streamResultsAnchor: streamResultsAnchor,
            shareItem: detailShareItem(vm),
            isPlayerOpening: $isPlayerOpening,
            playerOpeningError: $playerOpeningError,
            openingTorrentID: openingTorrentID,
            onPlayTorrent: { torrent in
                playTorrent(torrent, vm: vm)
            },
            onCast: {
                castBestAvailable(vm)
            },
            onShowRatingSheet: {
                prepareFeedbackDraft(vm)
                isShowingRatingSheet = true
            }
        )
        // Force a fresh detail scroll container per preview so a newly opened
        // show does not inherit the prior title's vertical offset.
        .id(previewTaskIdentity)
        .navigationTitle(preview.title)
        .overlay {
            if DetailRefreshLoadingPresentationPolicy.shouldShowBlockingOverlay(
                isLoadingDetail: vm.isLoading(.detail),
                isLoadingSeasonEpisodes: vm.isLoading(.seasonEpisodes),
                hasMediaItem: vm.mediaItem != nil
            ) {
                LoadingOverlay(
                    title: DetailRefreshLoadingPresentationPolicy.blockingOverlayTitle(
                        isLoadingSeasonEpisodes: vm.isLoading(.seasonEpisodes)
                    ),
                    message: "Fetching metadata and availability."
                )
            } else {
                EmptyView()
            }
        }
        .overlay(alignment: .top) {
            if DetailRefreshLoadingPresentationPolicy.shouldShowRefreshIndicator(
                isLoadingDetail: vm.isLoading(.detail),
                isLoadingSeasonEpisodes: vm.isLoading(.seasonEpisodes),
                hasMediaItem: vm.mediaItem != nil
            ) {
                InlineLoadingStatusView(title: DetailRefreshLoadingPresentationPolicy.refreshTitle)
                    .padding(.top, 16)
                    .transition(.move(edge: .top).combined(with: .opacity))
            } else {
                EmptyView()
            }
        }
        .appErrorAlert(
            "Detail Error",
            error: Binding(
                get: { vm.error },
                set: { vm.error = $0 }
            ),
            onRetry: {
                Task { await vm.retryLastFailedOperation(apiKey: metadataApiKey) }
            }
        )
        .overlay(alignment: .top) {
            if showActiveSessionToast {
                HStack(spacing: 8) {
                    Image(systemName: "play.circle.fill")
                        .font(.caption.weight(.semibold))
                    Text(DetailPresentationPolicy.activeSessionToastText)
                        .font(.caption.weight(.semibold))
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(.ultraThinMaterial, in: Capsule())
                .overlay {
                    Capsule()
                        .strokeBorder(.white.opacity(0.22), lineWidth: 0.5)
                }
                .shadow(color: .black.opacity(0.2), radius: 8, y: 2)
                .padding(.top, 16)
                .transition(.move(edge: .top).combined(with: .opacity))
            } else {
                EmptyView()
            }
        }
        .animation(.easeInOut(duration: 0.25), value: showActiveSessionToast)
    }

    private func prepareFeedbackDraft(_ vm: DetailViewModel) {
        draftFeedbackValue = DetailPresentationPolicy.feedbackDraftValue(
            currentValue: vm.currentFeedbackValue,
            scaleMode: vm.feedbackScaleMode
        )
    }

    private func detailShareItem(_ vm: DetailViewModel) -> String {
        DetailPresentationPolicy.shareItem(
            previewID: preview.id,
            previewTitle: preview.title,
            previewType: preview.type,
            previewTMDBID: preview.tmdbId,
            mediaTitle: vm.mediaItem?.title,
            mediaID: vm.mediaItem?.id,
            mediaTMDBID: vm.mediaItem?.tmdbId
        )
    }

    private func castBestAvailable(_ vm: DetailViewModel) {
        guard appState.activePlayerSession == nil else {
            showActiveSessionToast(for: appState.activePlayerSession)
            return
        }

        isPlayerOpening = true
        playerOpeningError = nil
        // Casting is not tied to a specific row; its feedback lives on the primary button / alert.
        openingTorrentID = nil

        streamResolutionTask?.cancel()
        streamResolutionTask = Task {
            defer { isPlayerOpening = false }

            if vm.torrentSearch.results.isEmpty {
                await vm.searchTorrents()
            }

            guard let torrent = vm.torrentSearch.results.first else {
                playerOpeningError = DetailPlaybackCopyPolicy.noStreamsMessage(for: .cast)
                return
            }

            if let stream = await vm.resolveStream(torrent: torrent) {
                await openPlayer(for: stream, vm: vm)
            } else {
                playerOpeningError = DetailPlaybackCopyPolicy.streamResolutionFailedMessage(for: .cast)
            }
        }
    }

    private func playTorrent(_ torrent: TorrentResult, vm: DetailViewModel) {
        guard appState.activePlayerSession == nil else {
            showActiveSessionToast(for: appState.activePlayerSession)
            return
        }

        // Immediately disable all play buttons and clear any previous error. Scope the inline
        // feedback to this specific row so only it shows the spinner / error.
        isPlayerOpening = true
        playerOpeningError = nil
        openingTorrentID = torrent.id

        streamResolutionTask?.cancel()
        streamResolutionTask = Task {
            defer { isPlayerOpening = false }
            if let stream = await vm.resolveStream(torrent: torrent) {
                await openPlayer(for: stream, vm: vm)
            } else {
                // Stream resolution returned nil — show error in this row (openingTorrentID
                // stays set so the failed row keeps its error + Try Again).
                playerOpeningError = DetailPlaybackCopyPolicy.streamResolutionFailedMessage(for: .playTorrent)
            }
        }
    }
}

private extension DetailView {
    var previewTaskIdentity: String {
        DetailQASamplePolicy.previewTaskIdentity(
            preview: preview,
            initialAction: initialAction
        )
    }

    @MainActor
    func runInitialActionIfNeeded(_ vm: DetailViewModel) async {
        guard !hasHandledInitialAction else { return }
        // One-tap Play on a TV recommendation carries no episode id and usually no watch
        // history, so resolveInitialEpisode leaves selectedEpisode nil and the action would
        // dead-end on a "missing episode" error. For a play-on-open intent, default to the
        // first available episode so one-tap play works for series, not just movies.
        if DetailInitialActionPolicy.isPlayOnOpen(initialAction),
           preview.type == .series,
           vm.selectedEpisode == nil,
           let defaultEpisode = vm.episodes.first {
            vm.selectEpisode(defaultEpisode)
        }
        let outcome = DetailInitialActionPolicy.resumePlaybackOutcome(
            action: initialAction,
            hasMediaItem: vm.mediaItem != nil,
            previewType: preview.type,
            hasSelectedEpisode: vm.selectedEpisode != nil,
            hasActivePlayerSession: appState.activePlayerSession != nil
        )
        let handling = DetailInitialActionHandlingPolicy.handling(for: outcome)

        guard handling != .deferUntilMediaLoads else {
            return
        }
        hasHandledInitialAction = true

        switch handling {
        case .deferUntilMediaLoads, .ignore:
            return
        case .showMissingEpisodeError:
            playerOpeningError = DetailPlaybackCopyPolicy.missingEpisodeMessage
            return
        case .showActiveSessionToast:
            showActiveSessionToast(for: appState.activePlayerSession)
            return
        case .beginPlayback:
            await beginInitialPlayback(vm)
        case .beginBestCachedPlayback:
            await beginBestCachedPlayback(vm)
        }
    }

    /// Resume-style playback: play the highest-ranked source (cached or not).
    @MainActor
    private func beginInitialPlayback(_ vm: DetailViewModel) async {
        isPlayerOpening = true
        playerOpeningError = nil
        // Not an explicit row tap — clear row scoping so feedback falls back to the broadcast
        // behaviour (and any error stays visible even though no single row is highlighted).
        openingTorrentID = nil
        defer { isPlayerOpening = false }

        if vm.torrentSearch.results.isEmpty {
            await vm.searchTorrents()
        }

        guard let torrent = vm.torrentSearch.results.first else {
            playerOpeningError = DetailPlaybackCopyPolicy.noStreamsMessage(for: .resumePlayback)
            return
        }

        if let stream = await vm.resolveStream(torrent: torrent) {
            await openPlayer(for: stream, vm: vm)
        } else {
            playerOpeningError = DetailPlaybackCopyPolicy.streamResolutionFailedMessage(for: .resumePlayback)
        }
    }

    /// One-tap play from a recommendation: search sources, wait (bounded) for
    /// cache enrichment, and play the best *confirmed-cached* source. Best-effort
    /// — if nothing is cached we simply land on Detail with no error and never
    /// force-play an uncached source (which would download/hang).
    @MainActor
    private func beginBestCachedPlayback(_ vm: DetailViewModel) async {
        isPlayerOpening = true
        playerOpeningError = nil
        // Not an explicit row tap — clear row scoping (see beginInitialPlayback).
        openingTorrentID = nil
        defer { isPlayerOpening = false }

        if vm.torrentSearch.results.isEmpty {
            await vm.searchTorrents()
        }

        // Bounded wait so a stalled debrid check can't hang the open; on timeout
        // we fall through to "land on Detail" rather than force-playing.
        guard let torrent = await vm.bestCachedTorrent(timeout: .seconds(12)) else {
            // No confirmed-cached source — land on Detail, no force-play.
            return
        }

        if let stream = await vm.resolveStream(torrent: torrent) {
            await openPlayer(for: stream, vm: vm)
        }
        // Stream resolution failure here is non-fatal: stay on Detail so the user
        // can pick a source manually rather than surfacing a blocking error.
    }

    @MainActor
    func runQAActionsIfNeeded(_ vm: DetailViewModel) async {
        guard DetailQAActionsPolicy.shouldRun(
            isQAEnabled: QARuntimeOptions.isEnabled,
            didRunQAActions: didRunQAActions,
            hasMediaItem: vm.mediaItem != nil
        ) else { return }
        didRunQAActions = true

        if let season = DetailQAActionsPolicy.seasonToLoad(
            previewType: preview.type,
            selectedSeason: QARuntimeOptions.selectedSeason,
            currentSeason: vm.selectedSeason
        ) {
            await vm.loadSeason(season, apiKey: metadataApiKey)
        }

        if let episode = DetailQAActionsPolicy.episodeToSelect(
            previewType: preview.type,
            selectedEpisode: QARuntimeOptions.selectedEpisode,
            episodes: vm.episodes
        ) {
            vm.selectEpisode(episode)
            await vm.searchTorrents()
        }

        for mutation in DetailQAActionsPolicy.libraryMutations(
            autoAddWatchlist: QARuntimeOptions.autoAddWatchlist,
            autoAddFavorites: QARuntimeOptions.autoAddFavorites,
            autoRemoveWatchlist: QARuntimeOptions.autoRemoveWatchlist,
            autoRemoveFavorites: QARuntimeOptions.autoRemoveFavorites,
            isInWatchlist: vm.isInWatchlist,
            isInFavorites: vm.isInFavorites
        ) {
            switch mutation {
            case .addWatchlist:
                await vm.toggleWatchlist()
            case .addFavorites:
                await vm.toggleFavorites()
            case .removeWatchlist:
                await vm.removeFromLibrary(listType: .watchlist)
            case .removeFavorites:
                await vm.removeFromLibrary(listType: .favorites)
            }
        }

        if let syntheticTorrent = QARuntimeOptions.syntheticTorrent {
            vm.torrents = [syntheticTorrent]
            vm.didSearch = true

            if QARuntimeOptions.autoPlaySyntheticTorrent,
               let stream = await vm.resolveStream(torrent: syntheticTorrent) {
                await openPlayer(for: stream, vm: vm)
            }
            return
        }

        guard let sampleStreams = makeQASampleStreams(using: vm),
              let sampleStream = sampleStreams.first else { return }

        if QARuntimeOptions.autoQueueSampleDownload {
            await queueQASampleDownload(sampleStream, vm: vm)
        }

        if QARuntimeOptions.autoPlaySample {
            await openPlayer(for: sampleStream, availableStreams: sampleStreams, vm: vm)
        }
    }

    func makeQASampleStreams(using vm: DetailViewModel) -> [StreamInfo]? {
        DetailQASamplePolicy.makeSampleStreams(
            sampleURLs: QARuntimeOptions.sampleURLs,
            mediaTitle: vm.mediaItem?.title ?? preview.title,
            previewType: preview.type,
            selectedEpisode: vm.selectedEpisode
        )
    }

    @MainActor
    func queueQASampleDownload(_ stream: StreamInfo, vm: DetailViewModel) async {
        guard let arguments = DetailQASamplePolicy.downloadArguments(
            mediaItem: vm.mediaItem,
            preview: preview,
            previewType: preview.type,
            selectedEpisode: vm.selectedEpisode
        ) else { return }
        _ = try? await appState.downloadManager.enqueueDownload(
            stream: stream,
            mediaId: arguments.mediaId,
            episodeId: arguments.episodeId,
            mediaTitle: arguments.mediaTitle,
            mediaType: arguments.mediaType,
            posterPath: arguments.posterPath,
            seasonNumber: arguments.seasonNumber,
            episodeNumber: arguments.episodeNumber,
            episodeTitle: arguments.episodeTitle
        )
        NotificationCenter.default.post(name: .downloadsDidChange, object: nil)
    }

    func openPlayer(
        for stream: StreamInfo,
        availableStreams: [StreamInfo]? = nil,
        vm: DetailViewModel
    ) async {
        guard DetailPlayerHandoffPolicy.route(
            hasActivePlayerSession: appState.activePlayerSession != nil,
            didLaunchPreferredExternalPlayer: false
        ) != .showActiveSessionToast else {
            showActiveSessionToast(for: appState.activePlayerSession)
            return
        }

        guard !Task.isCancelled else { return }
        let request = vm.makePlayerSessionRequest(
            stream: stream,
            preview: preview,
            availableStreams: availableStreams
        )
        let route = DetailPlayerHandoffPolicy.route(
            hasActivePlayerSession: appState.activePlayerSession != nil,
            didLaunchPreferredExternalPlayer: await launchWithPreferredPlayer(for: request.stream.streamURL)
        )
        if route == .showActiveSessionToast {
            showActiveSessionToast(for: appState.activePlayerSession)
            return
        }
        if route == .launchedExternally {
            return
        }
        guard !Task.isCancelled else { return }

        await MainActor.run {
            appState.activePlayerSession = request
            openWindow(id: "player", value: request)
        }
    }

    @MainActor
    func launchWithPreferredPlayer(for streamURL: URL) async -> Bool {
        let preference = await ExternalPlayerSettings.loadPreference(from: appState.settingsManager)
        guard let launchURL = ExternalPlayerRouting.launchURL(for: streamURL, preference: preference) else {
            return false
        }

        return await withCheckedContinuation { continuation in
            openURL(launchURL) { accepted in
                continuation.resume(returning: accepted)
            }
        }
    }

    func showActiveSessionToast(for session: PlayerSessionRequest?) {
        activeSessionToastTask?.cancel()
        showActiveSessionToast = true
        activeSessionToastTask = Task {
            try? await Task.sleep(for: .seconds(2.5))
            guard !Task.isCancelled else { return }
            showActiveSessionToast = false
        }
    }

    func scheduleAutoTorrentSearch(_ vm: DetailViewModel) {
        torrentAutoSearchTask?.cancel()
        torrentAutoSearchTask = Task {
            await Task.yield()
            guard !Task.isCancelled else { return }
            await vm.searchTorrents()
        }
    }
}
