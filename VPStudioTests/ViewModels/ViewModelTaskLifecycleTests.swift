import Foundation
import SwiftUI
import Testing
@testable import VPStudio

@Suite("ViewModel Task Lifecycle")
struct ViewModelTaskLifecycleTests {
    @Test
    func searchViewModelExposesCancellationHookForInFlightTasks() throws {
        let source = try contents(of: "VPStudio/ViewModels/Search/SearchViewModel.swift")
        #expect(source.contains("func cancelInFlightWork()"))
        #expect(source.contains("searchTask?.cancel()"))
        #expect(source.contains("searchTask = nil"))
        #expect(source.contains("loadMoreTask?.cancel()"))
        #expect(source.contains("loadMoreTask = nil"))
    }

    @Test
    func detailViewModelExposesCancellationHook() throws {
        let source = try contents(of: "VPStudio/ViewModels/Detail/DetailViewModel.swift")
        #expect(source.contains("searchTask?.cancel()"))
        #expect(source.contains("func cancelInFlightWork()"))
        #expect(source.contains("searchTask = nil"))
    }

    @Test
    func detailViewCancelsViewModelWorkOnDisappear() throws {
        let source = try contents(of: "VPStudio/Views/Windows/Detail/DetailView.swift")
        #expect(source.contains(".onDisappear"))
        #expect(source.contains("viewModel?.cancelInFlightWork()"))
        #expect(source.contains("metadataReloadTask?.cancel()"))
        #expect(source.contains("libraryReloadTask?.cancel()"))
        #expect(source.contains("feedbackReloadTask?.cancel()"))
        #expect(source.contains("streamResolutionTask?.cancel()"))
    }

    @Test
    func searchViewCancelsViewModelWorkOnDisappear() throws {
        let source = try contents(of: "VPStudio/Views/Windows/Search/SearchView.swift")
        #expect(source.contains(".onDisappear"))
        #expect(source.contains("viewModel.cancelInFlightWork()"))
    }

    @Test
    func detailViewCoalescesNotificationDrivenReloadTasks() throws {
        let source = try contents(of: "VPStudio/Views/Windows/Detail/DetailView.swift")
        #expect(source.contains("metadataReloadTask?.cancel()"))
        #expect(source.contains("metadataReloadTask = Task { await reloadDetailForLatestMetadataKey() }"))
        #expect(source.contains("libraryReloadTask?.cancel()"))
        #expect(source.contains("libraryReloadTask = Task { await vm.reloadLibraryState() }"))
        #expect(source.contains(".watchHistoryDidChange"))
        #expect(source.contains("feedbackReloadTask?.cancel()"))
        #expect(source.contains("feedbackReloadTask = Task { await vm.reloadFeedbackState() }"))
    }

    @Test
    func detailViewCoalescesStreamResolutionWorkPerSelection() throws {
        let source = try contents(of: "VPStudio/Views/Windows/Detail/DetailView.swift")
        #expect(source.contains("@State private var streamResolutionTask: Task<Void, Never>?"))
        #expect(source.contains("streamResolutionTask?.cancel()"))
        #expect(source.contains("streamResolutionTask = Task {"))
        #expect(source.contains("guard !Task.isCancelled else { return }"))
    }

    @Test
    func detailViewKeysInitialTaskToPreviewIdentity() throws {
        let source = try contents(of: "VPStudio/Views/Windows/Detail/DetailView.swift")
        #expect(source.contains(".task(id: previewTaskIdentity)"))
        #expect(source.contains("var previewTaskIdentity: String"))
        #expect(source.contains("preview.type.rawValue"))
        #expect(source.contains("preview.id"))
        #expect(source.contains("preview.tmdbId.map(String.init)"))
        #expect(source.contains("preview.episodeId"))
        #expect(source.contains("preview.seasonNumber.map(String.init)"))
        #expect(source.contains("preview.episodeNumber.map(String.init)"))
    }

    @Test
    func detailViewWiresBatchedTorrentRowsAndLoadMoreControl() throws {
        // Torrents section may live in DetailView.swift or extracted DetailTorrentsSection.swift
        let mainSource = try contents(of: "VPStudio/Views/Windows/Detail/DetailView.swift")
        let torrentSource = (try? contents(of: "VPStudio/Views/Windows/Detail/DetailTorrentsSection.swift")) ?? ""
        let source = mainSource + "\n" + torrentSource
        let hasResultLoop =
            source.contains("ForEach(vm.torrentSearch.results)") ||
            source.contains("ForEach(viewModel.torrentSearch.results)") ||
            source.contains("ForEach(Array(vm.torrentSearch.results.enumerated())")
        #expect(hasResultLoop)
        let hasLoadMoreCheck =
            source.contains("if vm.canLoadMoreTorrents") ||
            source.contains("if viewModel.canLoadMoreTorrents")
        #expect(hasLoadMoreCheck)
        let hasShownCount =
            source.contains("let shownCount = vm.torrentSearch.results.count") ||
            source.contains("let shownCount = viewModel.torrentSearch.results.count")
        #expect(hasShownCount)
        let hasTotalCount =
            source.contains("let totalCount = shownCount + vm.remainingTorrentCount") ||
            source.contains("let totalCount = shownCount + viewModel.remainingTorrentCount")
        #expect(hasTotalCount)
        let hasLoadMore =
            source.contains("vm.loadMoreTorrentResults()") ||
            source.contains("viewModel.loadMoreTorrentResults()")
        #expect(hasLoadMore)
        let hasNextBatch =
            source.contains("vm.nextTorrentBatchCount") ||
            source.contains("viewModel.nextTorrentBatchCount")
        #expect(hasNextBatch)
        let hasRemaining =
            source.contains("vm.remainingTorrentCount") ||
            source.contains("viewModel.remainingTorrentCount")
        #expect(hasRemaining)
    }

    @Test
    func detailViewEpisodeSelectionKeepsEpisodeContextAndTriggersSearch() throws {
        let layoutSource = try contents(of: "VPStudio/Views/Windows/Detail/SeriesDetailLayout.swift")
        let source = layoutSource
        let seasonsSectionBody: String
        if layoutSource.contains("private func episodesSection()") {
            let episodesBody = try functionBody(containing: "private func episodesSection()", in: layoutSource)
            let episodeCardBody = try functionBody(containing: "private func episodeCard(", in: layoutSource)
            seasonsSectionBody = episodesBody + "\n" + episodeCardBody
        } else {
            seasonsSectionBody = source
        }

        let hasEpisodeLoop = containsIgnoringWhitespace(
            seasonsSectionBody,
            "ForEach(viewModel.episodes) { episode in"
        ) || containsIgnoringWhitespace(
            seasonsSectionBody,
            "ForEach(vm.episodes) { episode in"
        )
        #expect(hasEpisodeLoop)
        let hasSelectEpisode = seasonsSectionBody.contains("vm.selectEpisode(episode)") ||
            seasonsSectionBody.contains("viewModel.selectEpisode(episode)")
        #expect(hasSelectEpisode)
        let hasSearchCall = seasonsSectionBody.contains("vm.searchTorrents()") ||
            seasonsSectionBody.contains("viewModel.searchTorrents()")
        #expect(hasSearchCall)

        if hasSearchCall {
            let selectToken = seasonsSectionBody.contains("viewModel.selectEpisode(episode)") ? "viewModel.selectEpisode(episode)" : "vm.selectEpisode(episode)"
            let selectRange = try requiredRange(of: selectToken, in: seasonsSectionBody)
            let searchToken = seasonsSectionBody.contains("viewModel.searchTorrents()") ? "viewModel.searchTorrents()" : "vm.searchTorrents()"
            let searchRange = try requiredRange(of: searchToken, in: seasonsSectionBody)
            #expect(selectRange.lowerBound < searchRange.lowerBound)
        }
    }

    @Test
    func detailViewKeysRenderedLayoutToPreviewIdentityAndAvoidsForcedResultScroll() throws {
        let detailSource = try contents(of: "VPStudio/Views/Windows/Detail/DetailView.swift")
        let layoutSource = try contents(of: "VPStudio/Views/Windows/Detail/SeriesDetailLayout.swift")

        let detailContentBody = try functionBody(containing: "func detailContent(", in: detailSource)
        #expect(detailContentBody.contains(".id(previewTaskIdentity)"))
        #expect(layoutSource.contains("ScrollView {"))
        // A user-initiated jump to the episode picker (episodeScrollRequest) is
        // allowed, but torrent-results loading must never force a scroll. Assert
        // every programmatic scroll targets the episodes section, nothing else.
        let totalScrollTo = layoutSource.components(separatedBy: ".scrollTo(").count - 1
        let episodeScrollTo = layoutSource.components(separatedBy: ".scrollTo(episodesSectionID").count - 1
        #expect(totalScrollTo == episodeScrollTo)
    }

    @Test
    func searchViewCoalescesMetadataReloadTask() throws {
        let source = try contents(of: "VPStudio/Views/Windows/Search/SearchView.swift")
        #expect(source.contains("metadataReloadTask?.cancel()"))
        #expect(source.contains("metadataReloadTask = Task { await reloadMetadataConfigurationAndSearch() }"))
    }

    @Test
    func searchViewCoalescesTasteProfileRatingReloadsAndCancelsOnDisappear() throws {
        let source = try contents(of: "VPStudio/Views/Windows/Search/SearchView.swift")
        #expect(source.contains("@State private var userRatingsReloadTask: Task<Void, Never>?"))
        #expect(source.contains("userRatingsReloadTask?.cancel()"))
        #expect(source.contains("userRatingsReloadTask = Task { await loadUserRatings(force: true) }"))
        #expect(source.contains("userRatingsReloadTask = nil"))
        #expect(source.contains("guard !Task.isCancelled else { return }"))
    }

    @Test
    func libraryViewCoalescesTasteProfileRatingReloadsAndCancelsOnDisappear() throws {
        let source = try contents(of: "VPStudio/Views/Windows/Library/LibraryView.swift")
        #expect(source.contains("@State private var userRatingsReloadTask: Task<Void, Never>?"))
        #expect(source.contains("userRatingsReloadTask?.cancel()"))
        #expect(source.contains("userRatingsReloadTask = Task { await loadUserRatings() }"))
        #expect(source.contains("userRatingsReloadTask = nil"))
        #expect(source.contains("guard !Task.isCancelled else { return }"))
    }

    @Test
    func searchViewUsesBrowseAwareEmptyStateCopy() throws {
        let source = try contents(of: "VPStudio/Views/Windows/Search/SearchView.swift")
        #expect(source.contains("ExploreEmptyView(query: emptyStateQuery)"))
        #expect(source.contains("private var emptyStateQuery: String"))
    }

    @Test
    func contentViewTerminatesDedicatedPlayerWhenMainWindowAppears() throws {
        let source = try contents(of: "VPStudio/Views/Windows/ContentView.swift")
        #expect(!source.contains("NotificationCenter.default.post(name: .mainWindowDidActivate, object: nil)"))
        #expect(source.contains("terminatePlayerIfMainWindowOpened()"))
        #expect(source.contains("markVisible: { appState.markMainWindowDidReappearForPlayer() }"))
        #expect(source.contains("markHidden: { appState.markMainWindowDidDisappearForPlayer() }"))
        #expect(source.contains("markVisible()"))
        #expect(source.contains("terminate()"))
        #expect(source.contains(".onDisappear(perform: markHidden)"))
        #expect(source.contains(".onChange(of: scenePhase)"))
        #expect(source.contains("guard phase == .active else { return }"))

        let body = try functionBody(containing: "private func terminatePlayerIfMainWindowOpened()", in: source)
        #expect(body.contains("guard appState.shouldTerminatePlayerForMainWindowActivation() else { return }"))

        #expect(body.contains("if let activeSession = appState.activePlayerSession"))
        #expect(body.contains("dismissWindow(id: \"player\", value: activeSession)"))
        #expect(body.contains("dismissWindow(id: \"player\")"))

        let valueDismissRange = try requiredRange(of: "dismissWindow(id: \"player\", value: activeSession)", in: body)
        let fallbackDismissRange = try requiredRange(of: "dismissWindow(id: \"player\")", in: body)
        let terminateRange = try requiredRange(of: "appState.terminateActivePlayerSession()", in: body)
        #expect(valueDismissRange.lowerBound < fallbackDismissRange.lowerBound)
        #expect(fallbackDismissRange.lowerBound < terminateRange.lowerBound)
    }

    @Test
    func discoverContinueWatchingClearsResumeStateBeforePlayerOpenHandoff() throws {
        let source = try contents(of: "VPStudio/Views/Windows/Discover/DiscoverView.swift")
        let body = try functionBody(containing: "private func handleContinueWatchingTap", in: source)

        #expect(!body.contains("defer { resumingItemID = nil }"))
        #expect(body.contains("let resumeItemID = preview.continueWatchingRowID"))
        #expect(body.contains("clearContinueWatchingResumeState(for: resumeItemID)"))
        #expect(source.contains("continueWatchingResumeTask?.cancel()"))
        #expect(source.contains("continueWatchingResumeTask = nil"))

        let clearRange = try requiredRange(of: "clearContinueWatchingResumeState(for: resumeItemID)", in: body)
        let activeSessionRange = try requiredRange(of: "appState.beginEmbeddedPlayerSession(request)", in: body)
        let openWindowRange = try requiredRange(of: "openWindow(id: \"player\", value: request)", in: body)
        #expect(clearRange.lowerBound < activeSessionRange.lowerBound)
        #expect(clearRange.lowerBound < openWindowRange.lowerBound)
    }

    @Test
    func detailViewUsesCentralEmbeddedPlayerHandoffBeforeOpeningPlayerWindow() throws {
        let source = try contents(of: "VPStudio/Views/Windows/Detail/DetailView.swift")
        let body = try functionBody(containing: "func openPlayer(", in: source)

        #expect(body.contains("appState.beginEmbeddedPlayerSession(request)"))
        let handoffRange = try requiredRange(of: "appState.beginEmbeddedPlayerSession(request)", in: body)
        let openWindowRange = try requiredRange(of: "openWindow(id: \"player\", value: request)", in: body)
        #expect(handoffRange.lowerBound < openWindowRange.lowerBound)
    }

    @Test
    func quickStartPromptRoutesSkipSetupToLibraryAndOnlyShowsOnDiscover() throws {
        let source = try contents(of: "VPStudio/Views/Windows/ContentView.swift")
        #expect(source.contains("Label(QuickStartPromptPolicy.skipSetupTitle, systemImage: \"books.vertical.fill\")"))
        #expect(source.contains("QuickStartPromptPolicy.skipSetupDestination"))
        #expect(source.contains("selectRootTab(QuickStartPromptPolicy.skipSetupDestination, state: state)"))
        #expect(source.contains("appState.isShowingSetup = true"))
        #expect(source.contains("if isShowingQuickStartPrompt, state.selectedTab == .discover"))
    }

    @Test
    func contentViewClearsRootNavigationPathForDirectTabMutations() throws {
        let source = try contents(of: "VPStudio/Views/Windows/ContentView.swift")
        #expect(source.contains("@State private var rootNavigationPath = NavigationPath()"))
        #expect(source.contains("NavigationStack(path: $rootNavigationPath)"))
        #expect(source.contains(".onChange(of: state.selectedTab) { previous, next in"))
        #expect(source.contains("RootTabSelectionPolicy.shouldClearNavigationPath(currentTab: previous, selectedTab: next)"))
        #expect(source.contains("rootNavigationPath = NavigationPath()"))
    }

    @Test
    func contentViewCoalescesNotificationDrivenBadgeRefreshTasks() throws {
        let source = try contents(of: "VPStudio/Views/Windows/ContentView.swift")
        #expect(source.contains("@State private var downloadBadgeRefreshTask: Task<Void, Never>?"))
        #expect(source.contains("@State private var settingsBadgeRefreshTask: Task<Void, Never>?"))
        #expect(source.contains("@State private var rootBadgeRefreshTask: Task<Void, Never>?"))
        #expect(source.contains("guard !disablesAutomaticTasks else { return }"))
        #expect(source.contains("scheduleDownloadBadgeRefresh()"))
        #expect(source.contains("scheduleSettingsBadgeRefresh()"))
        #expect(source.contains("scheduleRootBadgeRefresh()"))
        #expect(source.contains("cancelBadgeRefreshTasks()"))
        #expect(source.contains("downloadBadgeRefreshTask?.cancel()"))
        #expect(source.contains("settingsBadgeRefreshTask?.cancel()"))
        #expect(source.contains("rootBadgeRefreshTask?.cancel()"))
        #expect(source.contains("guard !Task.isCancelled else { return }"))
    }

    @Test
    func detailViewSupportsResumePlaybackInitialIntent() throws {
        let source = try contents(of: "VPStudio/Views/Windows/Detail/DetailView.swift")
        #expect(source.contains("enum DetailInitialAction"))
        #expect(source.contains("let initialAction: DetailInitialAction"))
        #expect(source.contains("func runInitialActionIfNeeded(_ vm: DetailViewModel) async"))
        #expect(source.contains("enum ResumePlaybackOutcome"))
        #expect(source.contains("case deferUntilMediaLoads"))
        #expect(source.contains("DetailInitialActionPolicy.resumePlaybackOutcome"))
        #expect(source.contains("case .searchAndPlay"))
        #expect(source.contains("await vm.searchTorrents()"))
        #expect(source.contains("await openPlayer(for: stream, vm: vm)"))
    }

    @Test
    func contentViewConfiguresDiscoverViewModelWithTheSharedDatabase() throws {
        let source = try contents(of: "VPStudio/Views/Windows/ContentView.swift")
        #expect(source.contains("discoverViewModel.configure(database: appState.database)"))
    }

    @Test
    func playerViewHandlesDedicatedPlayerDismissalFromThePlayerLifecycle() throws {
        let source = try contents(of: "VPStudio/Views/Windows/Player/PlayerView.swift")
        #expect(source.contains("dismissWindow(id: \"player\")"))
        #expect(source.contains("PlayerLifecyclePolicy.closesDedicatedPlayerWindowOnBack"))
        #expect(source.contains("PlayerLifecyclePolicy.dismissesCurrentPresentationOnBack"))
    }

    @Test
    func downloadsViewCoalescesNotificationReloadsAndCancelsOnDisappear() throws {
        let source = try contents(of: "VPStudio/Views/Windows/Downloads/DownloadsView.swift")
        #expect(source.contains("@State private var reloadTask: Task<Void, Never>?"))
        #expect(source.contains(".onDisappear"))
        #expect(source.contains("reloadTask?.cancel()"))
        #expect(source.contains("reloadTask = Task {"))
        #expect(source.contains("await vm.load()"))
        #expect(source.contains("await performQADownloadActionIfNeeded(vm)"))
    }

    @Test
    func downloadsViewRequiresConfirmationBeforeRemovingSingleTask() throws {
        let source = try contents(of: "VPStudio/Views/Windows/Downloads/DownloadsView.swift")
        #expect(source.contains("confirmDeleteTaskID = task.id"))
        #expect(source.contains(".confirmationDialog("))
        #expect(source.contains("Delete Download?"))
        #expect(source.contains("Task { await vm.remove(task) }"))
    }

    @Test
    func imdbImportPreviewStagingDoesNotAutoImport() throws {
        let source = try contents(of: "VPStudio/Views/Windows/Settings/Destinations/IMDbImportSettingsView.swift")
        #expect(source.contains(".fileImporter("))
        #expect(source.contains("selectedFileURL = url"))
        #expect(source.contains("await analyzeCSVHeaders(url: url)"))
        #expect(source.contains("previewDetected = true"))
        #expect(source.contains("isShowingPreview = false"))
    }

    @Test
    func seriesDetailEpisodeCardsUseSemanticButtonsAndAccessibility() throws {
        let source = try contents(of: "VPStudio/Views/Windows/Detail/SeriesDetailLayout.swift")
        #expect(source.contains("private func episodeCard(episode: Episode) -> some View"))
        #expect(source.contains("return Button {"))
        #expect(source.contains("viewModel.selectEpisode(episode)"))
        #expect(source.contains(".contextMenu {"))
        #expect(source.contains(".accessibilityLabel(SeriesDetailPresentationPolicy.episodeAccessibilityLabel("))
        #expect(source.contains("Press and hold for watched options."))
    }

    @Test
    func detailHeroArtworkPolicyUsesPosterCardForPosterOnlyArtwork() {
        #expect(DetailHeroArtworkPresentationPolicy.posterCardWidth == 132)
        #expect(DetailHeroArtworkPresentationPolicy.posterCardHeight == 198)
        #expect(DetailHeroArtworkPresentationPolicy.posterCardCornerRadius == 14)

        let backdropKind = DetailHeroArtworkPresentationPolicy.heroArtworkKind(
            backdropPath: "/series-backdrop.jpg",
            posterPath: "https://m.media-amazon.com/images/M/poster.jpg"
        )
        #expect(backdropKind == .backdrop)
        #expect(!DetailHeroArtworkPresentationPolicy.showsPosterCard(for: backdropKind))

        let posterOnlyKind = DetailHeroArtworkPresentationPolicy.heroArtworkKind(
            backdropPath: nil,
            posterPath: "https://m.media-amazon.com/images/M/poster.jpg"
        )
        #expect(posterOnlyKind == .posterOnly)
        #expect(DetailHeroArtworkPresentationPolicy.showsPosterCard(for: posterOnlyKind))

        let emptyKind = DetailHeroArtworkPresentationPolicy.heroArtworkKind(
            backdropPath: " ",
            posterPath: "javascript:alert(1)"
        )
        #expect(emptyKind == .none)
    }

    @Test
    func seriesDetailHeroDoesNotFallbackPosterIntoBackdropLayer() throws {
        let source = try contents(of: "VPStudio/Views/Windows/Detail/SeriesDetailLayout.swift")
        let heroImage = try functionBody(containing: "private var heroImage: some View", in: source)
        let heroOverlay = try functionBody(containing: "private var heroOverlay: some View", in: source)
        let heroOverlayBody = try functionBody(containing: "private func heroOverlayBody", in: source)

        #expect(!heroImage.contains("viewModel.mediaItem?.backdropURL ?? viewModel.mediaItem?.posterURL"))
        #expect(heroImage.contains("detailHeroArtworkKind == .backdrop"))
        #expect(heroImage.contains("AsyncImage(url: detailHeroBackdropURL)"))
        #expect(heroOverlay.contains("heroOverlayBody(availableWidth: proxy.size.width)"))
        #expect(source.contains("showsDetailHeroPosterCard(availableWidth: CGFloat)"))
        #expect(source.contains("availableWidth >= 680"))
        #expect(heroOverlayBody.contains("detailHeroPosterCard(url: detailHeroPosterURL)"))
        #expect(heroOverlayBody.contains("detailHeroTitleTrailingPadding(availableWidth: availableWidth)"))
        #expect(source.contains("detailHeroPosterPlaceholder(showsIcon: false)"))
        #expect(source.contains("detailHeroPosterPlaceholder(showsIcon: true)"))
    }

    @Test
    func environmentPreviewCardCancelsThumbnailDecodingWork() throws {
        let source = try contents(of: "VPStudio/Views/Windows/Discover/EnvironmentPreviewRow.swift")
        #expect(source.contains("@State private var thumbnailLoadTask: Task<Void, Never>?"))
        #expect(source.contains("thumbnailLoadTask?.cancel()"))
        #expect(source.contains("withTaskCancellationHandler"))
        #expect(source.contains("decodeTask.cancel()"))
        #expect(source.contains(".onDisappear"))
    }

    private func functionBody(containing signatureToken: String, in source: String) throws -> String {
        guard let signatureRange = source.range(of: signatureToken) else {
            throw NSError(
                domain: "ViewModelTaskLifecycleTests",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "Missing signature token: \(signatureToken)"]
            )
        }

        guard let openingBrace = source.range(
            of: "{",
            range: signatureRange.upperBound..<source.endIndex
        )?.lowerBound else {
            throw NSError(
                domain: "ViewModelTaskLifecycleTests",
                code: 2,
                userInfo: [NSLocalizedDescriptionKey: "Missing opening brace for signature token: \(signatureToken)"]
            )
        }

        var depth = 0
        var cursor = openingBrace
        while cursor < source.endIndex {
            let character = source[cursor]
            if character == "{" {
                depth += 1
            } else if character == "}" {
                depth -= 1
                if depth == 0 {
                    let bodyStart = source.index(after: openingBrace)
                    return String(source[bodyStart..<cursor])
                }
            }
            cursor = source.index(after: cursor)
        }

        throw NSError(
            domain: "ViewModelTaskLifecycleTests",
            code: 3,
            userInfo: [NSLocalizedDescriptionKey: "Missing closing brace for signature token: \(signatureToken)"]
        )
    }

    private func requiredRange(of token: String, in source: String) throws -> Range<String.Index> {
        guard let range = source.range(of: token) else {
            throw NSError(
                domain: "ViewModelTaskLifecycleTests",
                code: 4,
                userInfo: [NSLocalizedDescriptionKey: "Missing token: \(token)"]
            )
        }
        return range
    }

    private func firstCapture(in source: String, pattern: String) throws -> String {
        let regex = try NSRegularExpression(pattern: pattern)
        let nsSource = source as NSString
        let fullRange = NSRange(location: 0, length: nsSource.length)

        guard let match = regex.firstMatch(in: source, range: fullRange), match.numberOfRanges > 1 else {
            throw NSError(
                domain: "ViewModelTaskLifecycleTests",
                code: 5,
                userInfo: [NSLocalizedDescriptionKey: "Missing regex capture for pattern: \(pattern)"]
            )
        }

        let captureRange = match.range(at: 1)
        guard captureRange.location != NSNotFound else {
            throw NSError(
                domain: "ViewModelTaskLifecycleTests",
                code: 6,
                userInfo: [NSLocalizedDescriptionKey: "Missing capture group 1 for pattern: \(pattern)"]
            )
        }
        return nsSource.substring(with: captureRange)
    }

    private func containsIgnoringWhitespace(_ source: String, _ snippet: String) -> Bool {
        normalizedWhitespace(source).contains(normalizedWhitespace(snippet))
    }

    private func normalizedWhitespace(_ source: String) -> String {
        source
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func contents(of relativePath: String) throws -> String {
        let absolutePath = repoRootURL().appendingPathComponent(relativePath).path
        return try String(contentsOfFile: absolutePath, encoding: .utf8)
    }

    private func repoRootURL() -> URL {
        var url = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
        while !FileManager.default.fileExists(atPath: url.appendingPathComponent("Package.swift").path) {
            let parent = url.deletingLastPathComponent()
            if parent.path == url.path { break }
            url = parent
        }
        return url
    }
}
