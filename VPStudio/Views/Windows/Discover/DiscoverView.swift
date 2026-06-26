import SwiftUI

enum DiscoverInitialLoadPolicy {
    static func shouldStart(hasPerformedInitialLoad: Bool) -> Bool {
        !hasPerformedInitialLoad
    }

    /// Retained for completeness, but the initial-load latch is now set STICKY — synchronously,
    /// before the awaited metadata/AI fetch — so this is no longer consulted after the await. (See the
    /// `.task` in `DiscoverView`.) ContentView hosts tabs via a `switch`, so leaving Discover tears
    /// the view down and cancels its `.task`; latching before the await means a mid-flight tab leave
    /// cannot undo it, and the view model — held as ContentView `@State` — keeps the cache across the
    /// teardown/recreation round trip. A cancellation-gated mark (the old behavior) re-fired the slow
    /// metadata + AI load on every tab switch, which was BUG 5.
    static func shouldMarkCompleted(isCancelled: Bool) -> Bool {
        !isCancelled
    }
}

struct DiscoverMediaRowSpec: Identifiable, Equatable {
    let id: String
    let title: String
    let symbol: String
    let items: [MediaPreview]
    let animationDelay: Double
}

enum DiscoverHeroPresentationPolicy {
    static func heroItems(
        featuredBackdrops: [MediaPreview],
        trendingMovies: [MediaPreview],
        trendingShows: [MediaPreview],
        popularMovies: [MediaPreview],
        topRatedMovies: [MediaPreview],
        nowPlayingMovies: [MediaPreview],
        continueWatching: [MediaPreview]
    ) -> [MediaPreview] {
        if !featuredBackdrops.isEmpty {
            return Array(featuredBackdrops.prefix(5))
        }

        let fallbackSources = [
            trendingMovies,
            trendingShows,
            popularMovies,
            topRatedMovies,
            nowPlayingMovies,
            continueWatching,
        ]

        return fallbackSources.first(where: { !$0.isEmpty }).map { Array($0.prefix(5)) } ?? []
    }
}

enum DiscoverHeroArtworkPresentationPolicy {
    enum HeroArtworkKind: Equatable {
        case backdrop
        case posterOnly
        case none
    }

    static let posterCardWidth: CGFloat = 184
    static let posterCardHeight: CGFloat = 276
    static let posterCardCornerRadius: CGFloat = 18
    static let aiPosterCardWidth: CGFloat = 92
    static let aiPosterCardHeight: CGFloat = 138
    static let aiPosterCardCornerRadius: CGFloat = 12

    static func heroArtworkKind(backdropPath: String?, posterPath: String?) -> HeroArtworkKind {
        if hasRenderableArtworkPath(backdropPath, legacyTMDBSizePath: "w1280") {
            return .backdrop
        }
        if hasRenderableArtworkPath(posterPath, legacyTMDBSizePath: "w500") {
            return .posterOnly
        }
        return .none
    }

    static func showsPosterCard(for kind: HeroArtworkKind) -> Bool {
        kind == .posterOnly
    }

    private static func hasRenderableArtworkPath(_ value: String?, legacyTMDBSizePath: String) -> Bool {
        MediaArtworkURLPolicy.url(for: value, legacyTMDBSizePath: legacyTMDBSizePath) != nil
    }
}

enum DiscoverHierarchyPolicy {
    static let continueWatchingDelay = 0.02
    static let firstCatalogDelay = 0.05
    static let catalogDelayStep = 0.07

    static func shouldShowContinueWatching(count: Int) -> Bool {
        count > 0
    }

    static func animationDelay(forVisibleCatalogIndex index: Int) -> Double {
        firstCatalogDelay + (Double(index) * catalogDelayStep)
    }

    static func visibleCatalogRows(
        trendingMovies: [MediaPreview],
        trendingShows: [MediaPreview],
        popularMovies: [MediaPreview],
        topRatedMovies: [MediaPreview],
        nowPlayingMovies: [MediaPreview],
        enabledCatalogs: Set<DiscoverCatalogKind> = DiscoverCatalogPreferencesPolicy.defaultKinds
    ) -> [DiscoverMediaRowSpec] {
        let candidates: [(kind: DiscoverCatalogKind, items: [MediaPreview])] = [
            (.trendingMovies, trendingMovies),
            (.trendingShows, trendingShows),
            (.popularMovies, popularMovies),
            (.topRatedMovies, topRatedMovies),
            (.nowPlayingMovies, nowPlayingMovies),
        ]

        return candidates
            .filter { enabledCatalogs.contains($0.kind) && !$0.items.isEmpty }
            .enumerated()
            .map { index, row in
                DiscoverMediaRowSpec(
                    id: row.kind.rowID,
                    title: row.kind.title,
                    symbol: row.kind.symbol,
                    items: row.items,
                    animationDelay: animationDelay(forVisibleCatalogIndex: index)
                )
            }
    }
}

struct DiscoverAICuratedSectionState: Equatable {
    let isLoading: Bool
    let isRegenerateEnabled: Bool
    let primaryRecommendation: AIMovieRecommendation?
    let primaryPreview: MediaPreview?
    let supportingRecommendations: [AIMovieRecommendation]
    let showsEmptyState: Bool
}

enum DiscoverAICuratedSectionPolicy {
    static let helperCopy = "Picked from your watchlist, favorites, ratings, and recent activity."
    static let maxSupportingRecommendations = 3

    static func makeState(
        enabled: Bool,
        isLoading: Bool,
        heroPreview: MediaPreview?,
        recommendations: [AIMovieRecommendation]
    ) -> DiscoverAICuratedSectionState? {
        guard enabled else { return nil }

        if isLoading {
            return DiscoverAICuratedSectionState(
                isLoading: true,
                isRegenerateEnabled: false,
                primaryRecommendation: nil,
                primaryPreview: nil,
                supportingRecommendations: [],
                showsEmptyState: false
            )
        }

        return DiscoverAICuratedSectionState(
            isLoading: false,
            isRegenerateEnabled: true,
            primaryRecommendation: recommendations.first,
            primaryPreview: heroPreview,
            supportingRecommendations: Array(recommendations.dropFirst().prefix(maxSupportingRecommendations)),
            showsEmptyState: recommendations.isEmpty
        )
    }
}

enum DiscoverLoadingPresentationMode: Equatable {
    case blockingSkeleton
    case refreshingRetainedContent
    case content
}

enum DiscoverLoadingPresentationPolicy {
    static let refreshTitle = "Refreshing Discover"

    static func presentationMode(
        isLoading: Bool,
        featuredBackdropCount: Int,
        continueWatchingCount: Int,
        catalogRowCount: Int,
        aiRecommendationCount: Int
    ) -> DiscoverLoadingPresentationMode {
        guard isLoading else { return .content }

        let hasRenderableContent = featuredBackdropCount > 0
            || continueWatchingCount > 0
            || catalogRowCount > 0
            || aiRecommendationCount > 0

        return hasRenderableContent ? .refreshingRetainedContent : .blockingSkeleton
    }
}

struct DiscoverErrorPresentation: Equatable {
    let isSetupError: Bool
    let artworkName: String
    let tagText: String
    let tagSymbol: String
    let headline: String
    let message: String
    let retryTitle: String
}

enum DiscoverErrorPresentationPolicy {
    static let setupInlineMessage = "Add your OMDb key in Settings, then come back here for metadata, posters, and Discover rows. Library and Downloads keep working in the meantime."

    static func presentation(for error: AppError) -> DiscoverErrorPresentation {
        let isSetupError = error.requiresMetadataSetupAction
        return DiscoverErrorPresentation(
            isSetupError: isSetupError,
            artworkName: isSetupError ? "genre-art-new" : "genre-art-deep",
            tagText: isSetupError ? "Setup needed" : "Discover needs attention",
            tagSymbol: isSetupError ? "sparkles" : "arrow.clockwise",
            headline: isSetupError ? "Finish setup to unlock Discover" : (error.errorDescription ?? "Discover hit a snag"),
            message: inlineMessage(for: error, isSetupError: isSetupError),
            retryTitle: isSetupError ? "Retry Later" : "Retry"
        )
    }

    private static func inlineMessage(for error: AppError, isSetupError: Bool) -> String {
        if isSetupError {
            return setupInlineMessage
        }

        if let suggestion = error.recoverySuggestion, !suggestion.isEmpty {
            return suggestion
        }

        return error.errorDescription ?? "Something went wrong."
    }
}

struct DiscoverDetailRoute: Identifiable, Hashable {
    let preview: MediaPreview
    let initialAction: DetailInitialAction

    var id: String {
        [
            preview.id,
            preview.episodeId ?? "none",
            initialAction.rawValue
        ].joined(separator: "-")
    }
}

private struct DiscoverLockedPreviewTile: View {
    let index: Int

    private var accent: Color {
        switch index % 5 {
        case 0: return .yellow
        case 1: return .pink
        case 2: return .teal
        case 3: return .purple
        default: return .orange
        }
    }

    var body: some View {
        RoundedRectangle(cornerRadius: 16, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [
                        accent.opacity(0.16),
                        Color.white.opacity(0.08),
                        Color.white.opacity(0.03),
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay {
                Image(systemName: index.isMultiple(of: 2) ? "play.rectangle" : "film")
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.34))
            }
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(
                        .white.opacity(0.22),
                        style: StrokeStyle(lineWidth: 1, dash: [6, 5])
                    )
            }
            .frame(width: 112, height: 132)
            .opacity(0.86)
    }
}

enum DiscoverNavigationPolicy {
    static func browseRoute(for preview: MediaPreview) -> DiscoverDetailRoute {
        DiscoverDetailRoute(preview: preview, initialAction: .none)
    }

    static func continueWatchingRoute(for preview: MediaPreview) -> DiscoverDetailRoute {
        DiscoverDetailRoute(preview: preview, initialAction: .resumePlayback)
    }
}

struct DiscoverView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.accessibilityVoiceOverEnabled) private var accessibilityVoiceOverEnabled
    @Environment(\.openWindow) private var openWindow
    @Environment(\.openURL) private var openURL
    @AppStorage(VPDesignFlags.useObsidianGlassKey) private var useObsidianGlass = true
    @AppStorage(DiscoverCatalogPreferencesPolicy.storageKey) private var enabledCatalogIDs = DiscoverCatalogPreferencesPolicy.defaultStorageValue
    @Bindable var viewModel: DiscoverViewModel
    /// When the first-run Quick Start prompt is on screen, suppress Discover's own setup panel so
    /// the user isn't shown two competing "finish setup" surfaces at once.
    var suppressSetupSurface: Bool = false
    /// Pushed detail route for the Discover tab, hoisted to AppState so it survives the player
    /// dismissing/re-opening the main window (see `AppState.discoverDetailRoute`).
    private var discoverRoute: Binding<DiscoverDetailRoute?> {
        Binding(get: { appState.discoverDetailRoute }, set: { appState.discoverDetailRoute = $0 })
    }
    @State private var currentHeroIndex = 0
    @State private var metadataReloadTask: Task<Void, Never>?
    @State private var userRatingsReloadTask: Task<Void, Never>?
    @State private var recommendationsFilterTask: Task<Void, Never>?
    @State private var userRatings: [String: TasteEvent] = [:]
    /// The Continue Watching item currently being resolved for direct resume (drives the tile
    /// spinner and prevents duplicate taps while debrid re-resolves the stored source).
    @State private var resumingItemID: String?
    @State private var continueWatchingResumeTask: Task<Void, Never>?

    private var catalogRows: [DiscoverMediaRowSpec] {
        DiscoverHierarchyPolicy.visibleCatalogRows(
            trendingMovies: viewModel.trendingMovies,
            trendingShows: viewModel.trendingShows,
            popularMovies: viewModel.popularMovies,
            topRatedMovies: viewModel.topRatedMovies,
            nowPlayingMovies: viewModel.nowPlayingMovies,
            enabledCatalogs: enabledCatalogs
        )
    }

    private var enabledCatalogs: Set<DiscoverCatalogKind> {
        DiscoverCatalogPreferencesPolicy.enabledKinds(from: enabledCatalogIDs)
    }

    private var aiCuratedSectionState: DiscoverAICuratedSectionState? {
        DiscoverAICuratedSectionPolicy.makeState(
            enabled: viewModel.aiRecommendationsEnabled,
            isLoading: viewModel.isLoadingAIRecommendations,
            heroPreview: viewModel.aiHeroPreview,
            recommendations: viewModel.aiRecommendations
        )
    }

    private var heroItems: [MediaPreview] {
        DiscoverHeroPresentationPolicy.heroItems(
            featuredBackdrops: viewModel.featuredBackdrops,
            trendingMovies: viewModel.trendingMovies,
            trendingShows: viewModel.trendingShows,
            popularMovies: viewModel.popularMovies,
            topRatedMovies: viewModel.topRatedMovies,
            nowPlayingMovies: viewModel.nowPlayingMovies,
            continueWatching: viewModel.continueWatching.map(\.preview)
        )
    }

    private var discoverLoadingPresentation: DiscoverLoadingPresentationMode {
        DiscoverLoadingPresentationPolicy.presentationMode(
            isLoading: viewModel.isLoading,
            featuredBackdropCount: viewModel.featuredBackdrops.count,
            continueWatchingCount: viewModel.continueWatching.count,
            catalogRowCount: catalogRows.count,
            aiRecommendationCount: viewModel.aiRecommendations.count
        )
    }

    private var suppressedSetupBackdropPresentation: DiscoverErrorPresentation? {
        guard suppressSetupSurface, let error = viewModel.error else { return nil }
        let presentation = DiscoverErrorPresentationPolicy.presentation(for: error)
        guard DiscoverSetupSurfacePolicy.showsSuppressedSetupBackdrop(
            suppressSetupSurface: suppressSetupSurface,
            isSetupError: presentation.isSetupError
        ) else { return nil }
        return presentation
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 36) {
                if let error = viewModel.error, !suppressSetupSurface {
                    discoverStatePanel(error: error)
                    if DiscoverErrorPresentationPolicy.presentation(for: error).isSetupError {
                        discoverLockedPreviewRows
                    }
                } else if let presentation = suppressedSetupBackdropPresentation {
                    discoverSuppressedSetupBackdrop(presentation: presentation)
                }

                if discoverLoadingPresentation == .blockingSkeleton {
                    DiscoverSkeletonView()
                        .transition(.opacity)
                } else {
                    if discoverLoadingPresentation == .refreshingRetainedContent {
                        InlineLoadingStatusView(title: DiscoverLoadingPresentationPolicy.refreshTitle)
                            .padding(.horizontal, 8)
                            .transition(.opacity.combined(with: .move(edge: .top)))
                    }

                    // Cinematic hero carousel
                    if !heroItems.isEmpty {
                        TabView(selection: $currentHeroIndex) {
                            ForEach(Array(heroItems.enumerated()), id: \.element.id) { index, featured in
                                FeaturedHeroView(item: featured) {
                                    appState.discoverDetailRoute = DiscoverNavigationPolicy.browseRoute(for: featured)
                                }
                                .tag(index)
                            }
                        }
                        #if !os(macOS)
                        .tabViewStyle(.page(indexDisplayMode: .never))
                        #endif
                        // Match the hero's own height (540) — the legacy 604 left a 64pt dead
                        // band below the card now that the default page dots are hidden, which
                        // the custom indicator was floating in.
                        .frame(height: 540)
                        // Premium bar-style page indicator (Apple TV+ feel) instead of the
                        // default UIPageControl dots.
                        .overlay(alignment: .bottom) {
                            if heroItems.count > 1 {
                                HStack(spacing: 6) {
                                    ForEach(heroItems.indices, id: \.self) { idx in
                                        Capsule()
                                            .fill(idx == currentHeroIndex ? VPColor.accent : Color.white.opacity(0.32))
                                            .frame(width: idx == currentHeroIndex ? 22 : 6, height: 6)
                                    }
                                }
                                .padding(.bottom, 20)
                                .animation(.easeInOut(duration: 0.25), value: currentHeroIndex)
                            }
                        }
                        .transition(.opacity.combined(with: .move(edge: .top)))
                    }

                    if DiscoverHierarchyPolicy.shouldShowContinueWatching(count: viewModel.continueWatching.count) {
                        MediaRow(
                            title: "Continue Watching",
                            symbol: "play.circle",
                            items: viewModel.continueWatching.map(\.preview),
                            userRatings: userRatings,
                            animationDelay: DiscoverHierarchyPolicy.continueWatchingDelay,
                            progressByItemID: continueWatchingProgress,
                            lastFrameByItemID: continueWatchingFrames,
                            resumingItemID: resumingItemID
                        ) { item in
                            handleContinueWatchingTap(item)
                        }
                    }

                    aiCuratedSection

                    ForEach(catalogRows) { row in
                        MediaRow(
                            title: row.title,
                            symbol: row.symbol,
                            items: row.items,
                            userRatings: userRatings,
                            animationDelay: row.animationDelay
                        ) { item in
                            appState.discoverDetailRoute = DiscoverNavigationPolicy.browseRoute(for: item)
                        }
                    }
                }
            }
            .animation(.easeOut(duration: 0.25), value: discoverLoadingPresentation)
            .padding(.horizontal, 4)
            .padding(.bottom, DiscoverLayoutPolicy.bottomContentPadding(for: appState.navigationLayout))
        }
        .background {
            if useObsidianGlass {
                VPBackground()
            } else {
                VPMenuBackground()
                    .ignoresSafeArea()
            }
        }
        #if !os(macOS)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .navigationBar)
        #endif
        .navigationDestination(item: discoverRoute) { route in
            DetailView(preview: route.preview, initialAction: route.initialAction)
        }
        .refreshable {
            await viewModel.refresh()
        }
        .task {
            guard DiscoverInitialLoadPolicy.shouldStart(
                hasPerformedInitialLoad: viewModel.hasPerformedInitialLoad
            ) else { return }
            // Latch BEFORE the await so leaving the Discover tab (which cancels this `.task`)
            // mid-fetch cannot undo it and re-fire the slow metadata + AI load on the next tab switch.
            // The view model lives on ContentView as `@State`, so the latch — and the cache it
            // guards — persists across the view teardown/recreation.
            viewModel.hasPerformedInitialLoad = true
            await reloadDiscoverForLatestMetadataKey()
        }
        .task(id: accessibilityVoiceOverEnabled) {
            guard !accessibilityVoiceOverEnabled else { return }
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(8))
                guard !Task.isCancelled else { break }
                guard heroItems.count > 1 else { continue }
                withAnimation(.easeInOut(duration: 0.8)) {
                    currentHeroIndex = (currentHeroIndex + 1) % heroItems.count
                }
            }
        }
        .onChange(of: heroItems.map(\.id)) { _, newIDs in
            if currentHeroIndex >= newIDs.count {
                currentHeroIndex = 0
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .metadataApiKeyDidChange)) { _ in
            metadataReloadTask?.cancel()
            metadataReloadTask = Task { await reloadDiscoverForLatestMetadataKey() }
        }
        .task {
            await loadUserRatings()
        }
        .onReceive(NotificationCenter.default.publisher(for: .tasteProfileDidChange)) { _ in
            userRatingsReloadTask?.cancel()
            userRatingsReloadTask = Task {
                await loadUserRatings()
                await viewModel.refreshLocalPersonalizationState()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .libraryDidChange)) { _ in
            recommendationsFilterTask?.cancel()
            recommendationsFilterTask = Task {
                await viewModel.refreshLocalPersonalizationState()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .watchHistoryDidChange)) { _ in
            recommendationsFilterTask?.cancel()
            recommendationsFilterTask = Task {
                await viewModel.refreshLocalPersonalizationState()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .discoverAISettingsDidChange)) { _ in
            recommendationsFilterTask?.cancel()
            recommendationsFilterTask = Task {
                await viewModel.reloadAIRecommendationSettings(
                    aiManager: appState.aiAssistantManager,
                    settingsManager: appState.settingsManager
                )
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .appDidResetAllData)) { _ in
            recommendationsFilterTask?.cancel()
            recommendationsFilterTask = Task {
                await viewModel.reloadAIRecommendationSettings(
                    aiManager: appState.aiAssistantManager,
                    settingsManager: appState.settingsManager
                )
            }
        }
        .onDisappear {
            metadataReloadTask?.cancel()
            userRatingsReloadTask?.cancel()
            recommendationsFilterTask?.cancel()
        }
    }

    private var secondarySetupActionTint: Color {
        .white.opacity(0.95)
    }

    private var secondarySetupActionForeground: Color {
        .white.opacity(0.9)
    }

    private var discoverLockedPreviewRows: some View {
        VStack(alignment: .leading, spacing: 18) {
            ForEach(0 ..< DiscoverSetupSurfacePolicy.lockedPreviewRowCount, id: \.self) { row in
                VStack(alignment: .leading, spacing: 12) {
                    GlassTag(
                        text: row == 0 ? "Preview locked" : "Popular preview",
                        tintColor: .white.opacity(0.48),
                        symbol: row == 0 ? "lock.fill" : "star",
                        weight: .semibold,
                        foregroundColor: .white.opacity(0.92)
                    )
                    HStack(spacing: 14) {
                        ForEach(0 ..< 5, id: \.self) { index in
                            DiscoverLockedPreviewTile(index: row * 5 + index)
                        }
                    }
                }
            }
        }
        .padding(.horizontal, 8)
        .padding(.top, 4)
        .accessibilityHidden(true)
        .allowsHitTesting(false)
    }

    @ViewBuilder
    private func discoverSuppressedSetupBackdrop(presentation: DiscoverErrorPresentation) -> some View {
        CinematicStateCard(
            accent: .yellow,
            artworkName: presentation.artworkName,
            minHeight: 360
        ) {
            VStack(alignment: .leading, spacing: 20) {
                HStack(alignment: .top, spacing: 16) {
                    Image(systemName: "sparkles.tv.fill")
                        .font(.system(size: 34, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 64, height: 64)
                        .background(.yellow.opacity(0.26), in: Circle())
                        .overlay {
                            Circle()
                                .strokeBorder(.white.opacity(0.18), lineWidth: 1)
                        }

                    VStack(alignment: .leading, spacing: 8) {
                        GlassTag(
                            text: "Ready when you are",
                            tintColor: .yellow.opacity(0.34),
                            symbol: "sparkles",
                            weight: .semibold,
                            foregroundColor: .white.opacity(0.92)
                        )
                        Text(presentation.headline)
                            .font(.largeTitle.weight(.bold))
                            .foregroundStyle(.white)
                            .lineLimit(2)
                            .minimumScaleFactor(0.76)
                        Text(presentation.message)
                            .font(.body)
                            .foregroundStyle(.white.opacity(0.78))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                FlowLayout(spacing: 10) {
                    GlassTag(
                        text: "Trending rows",
                        tintColor: .white.opacity(0.36),
                        symbol: "rectangle.grid.1x2",
                        weight: .semibold,
                        foregroundColor: .white.opacity(0.88)
                    )
                    GlassTag(
                        text: "Hero artwork",
                        tintColor: .white.opacity(0.36),
                        symbol: "photo.on.rectangle.angled",
                        weight: .semibold,
                        foregroundColor: .white.opacity(0.88)
                    )
                    GlassTag(
                        text: "Search and streams",
                        tintColor: .white.opacity(0.36),
                        symbol: "play.rectangle.on.rectangle",
                        weight: .semibold,
                        foregroundColor: .white.opacity(0.88)
                    )
                }
            }
        }
        .padding(.top, 72)
        .padding(.horizontal, 8)
        .transition(.opacity.combined(with: .move(edge: .top)))
    }

    @ViewBuilder
    private func discoverStatePanel(error: AppError) -> some View {
        let presentation = DiscoverErrorPresentationPolicy.presentation(for: error)
        let accent: Color = presentation.isSetupError ? .yellow : .orange

        CinematicStateCard(
            accent: accent,
            artworkName: presentation.isSetupError ? nil : presentation.artworkName,
            minHeight: presentation.isSetupError ? 340 : 228
        ) {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .top, spacing: 14) {
                    Image(systemName: presentation.isSetupError ? "sparkles.rectangle.stack.fill" : "exclamationmark.triangle.fill")
                        .font(.system(size: 26, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 50, height: 50)
                        .background(accent.opacity(0.26), in: Circle())
                        .overlay {
                            Circle()
                                .strokeBorder(.white.opacity(0.16), lineWidth: 1)
                        }

                    VStack(alignment: .leading, spacing: 6) {
                        GlassTag(
                            text: presentation.tagText,
                            tintColor: accent.opacity(0.22),
                            symbol: presentation.tagSymbol
                        )
                        Text(presentation.headline)
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(.white)
                        Text(presentation.message)
                            .font(.subheadline)
                            .foregroundStyle(presentation.isSetupError ? .white.opacity(0.82) : .secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Spacer(minLength: 0)

                    Button {
                        viewModel.error = nil
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title3)
                            .foregroundStyle(presentation.isSetupError ? .white.opacity(0.78) : .secondary)
                            .frame(width: 32, height: 32)
                            .background(.white.opacity(0.08), in: Circle())
                            .overlay {
                                Circle()
                                    .strokeBorder(.white.opacity(0.12), lineWidth: 1)
                            }
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(presentation.isSetupError ? "Dismiss setup message" : "Dismiss error message")
                }

                FlowLayout(spacing: 10) {
                    if presentation.isSetupError {
                        SpatialButton(title: "Open Settings", icon: "gearshape.fill", tint: .yellow) {
                            appState.selectedTab = .settings
                            viewModel.error = nil
                        }
                    }

                    if !presentation.isSetupError {
                        Button {
                            if DiscoverErrorActionPolicy.retryBehavior(isSetupError: presentation.isSetupError) == .refreshAndDismiss {
                                Task { await viewModel.refresh() }
                            }
                            viewModel.error = nil
                        } label: {
                            GlassTag(
                                text: presentation.retryTitle,
                                tintColor: secondarySetupActionTint,
                                symbol: "arrow.clockwise",
                                foregroundColor: secondarySetupActionForeground
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .frame(
                maxWidth: .infinity,
                minHeight: presentation.isSetupError ? 220 : 0,
                alignment: .leading
            )
        }
    }

    // MARK: - AI Curated Section

    @ViewBuilder
    private var aiCuratedSection: some View {
        if let state = aiCuratedSectionState {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 8) {
                        Image(systemName: "sparkles")
                            .font(.headline)
                            .foregroundStyle(.purple)
                        Text("Curated For You")
                            .font(.headline)
                            .foregroundStyle(.white)
                        Spacer()
                        Button {
                            Task {
                                await viewModel.regenerateAIRecommendations(
                                    aiManager: appState.aiAssistantManager,
                                    settingsManager: appState.settingsManager
                                )
                            }
                        } label: {
                            HStack(spacing: 6) {
                                if state.isLoading {
                                    ProgressView()
                                        .controlSize(.mini)
                                } else {
                                    Image(systemName: "arrow.trianglehead.2.clockwise")
                                        .font(.system(size: 12, weight: .semibold))
                                }

                                Text(state.isLoading ? "Refreshing…" : "Regenerate")
                                    .font(.system(size: 12, weight: .semibold))
                            }
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(.ultraThinMaterial, in: Capsule())
                            .overlay {
                                Capsule()
                                    .strokeBorder(
                                        LinearGradient(
                                            colors: [.white.opacity(0.28), .white.opacity(0.06)],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        ),
                                        lineWidth: 1
                                    )
                            }
                        }
                        .buttonStyle(.plain)
                        .disabled(!state.isRegenerateEnabled)
                        .opacity(state.isRegenerateEnabled ? 1 : 0.7)
                        #if os(visionOS)
                        .hoverEffect(.highlight)
                        #endif
                    }

                    Text(DiscoverAICuratedSectionPolicy.helperCopy)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 8)

                if state.isLoading {
                    aiCuratedLoadingView
                } else if state.showsEmptyState {
                    aiCuratedEmptyState
                } else if let primaryRecommendation = state.primaryRecommendation {
                    let primaryPreview = state.primaryPreview ?? primaryRecommendation.toMediaPreview()

                    VStack(alignment: .leading, spacing: 14) {
                        AICuratedHeroCard(
                            preview: primaryPreview,
                            recommendation: primaryRecommendation
                        ) {
                            appState.discoverDetailRoute = DiscoverNavigationPolicy.browseRoute(for: primaryPreview)
                        }

                        if !state.supportingRecommendations.isEmpty {
                            VStack(spacing: 10) {
                                ForEach(state.supportingRecommendations) { recommendation in
                                    let recommendationPreview = viewModel.aiPreview(for: recommendation)
                                    AICuratedSupportingRow(recommendation: recommendation) {
                                        appState.discoverDetailRoute = DiscoverNavigationPolicy.browseRoute(for: recommendationPreview)
                                    }
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 8)
                }
            }
            .transition(.opacity.combined(with: .move(edge: .top)))
        }
    }

    private var aiCuratedLoadingView: some View {
        VStack(alignment: .leading, spacing: 12) {
            SkeletonBlock(width: 560, height: 236, cornerRadius: 22)

            ForEach(0 ..< 3, id: \.self) { _ in
                SkeletonBlock(width: 420, height: 62, cornerRadius: 16)
            }
        }
        .padding(.horizontal, 8)
    }

    private var aiCuratedEmptyState: some View {
        ContentUnavailableView(
            "No AI picks yet",
            systemImage: "sparkles.tv",
            description: Text("Rate a few titles or add more to your library, then regenerate for fresh recommendations.")
        )
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 8)
        .padding(.vertical, 12)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20))
        .glassStroke(cornerRadius: 20)
        .glassShadow()
    }

    @MainActor
    private func loadUserRatings() async {
        let events = (try? await appState.database.fetchTasteEvents(eventType: .rated, limit: 500)) ?? []
        userRatings = TasteRatingLookupPolicy.lookup(from: events)
    }

    @MainActor
    private func reloadDiscoverForLatestMetadataKey() async {
        let key = (try? await appState.settingsManager.getMetadataApiKey()) ?? ""
        viewModel.configure(database: appState.database)
        currentHeroIndex = 0
        await viewModel.load(apiKey: key)
        await viewModel.refreshResolvedAIPreviewsIfNeeded()
        await viewModel.loadAIRecommendationsIfNeeded(
            aiManager: appState.aiAssistantManager,
            settingsManager: appState.settingsManager
        )
    }

    /// Per-item watch progress (0...1) for Continue Watching tiles, keyed by preview id.
    private var continueWatchingProgress: [String: Double] {
        var result: [String: Double] = [:]
        for entry in viewModel.continueWatching {
            result[entry.preview.continueWatchingRowID] = entry.history.progressPercent
        }
        return result
    }

    /// Per-item last-frame artwork file URLs for Continue Watching tiles, keyed by row id.
    private var continueWatchingFrames: [String: URL] {
        var result: [String: URL] = [:]
        for entry in viewModel.continueWatching {
            if let path = entry.history.lastFrameImagePath {
                result[entry.preview.continueWatchingRowID] = URL(fileURLWithPath: path)
            }
        }
        return result
    }

    /// Continue Watching tap: resume playback directly at the saved position instead of opening
    /// the detail page. Tries the stored stream reference (fast, no indexer search); if that is
    /// unavailable or fails, falls back to the detail route which performs a fresh search.
    private func handleContinueWatchingTap(_ preview: MediaPreview) {
        // If something is already playing, defer to the detail route (it shows the
        // "already playing" toast and avoids opening a second player window).
        guard appState.activePlayerSession == nil else {
            appState.discoverDetailRoute = DiscoverNavigationPolicy.continueWatchingRoute(for: preview)
            return
        }
        // Ignore repeat taps while a resume is already resolving.
        guard resumingItemID == nil else { return }
        guard let entry = viewModel.continueWatching.first(where: {
            $0.preview.continueWatchingRowID == preview.continueWatchingRowID
        }) else {
            appState.discoverDetailRoute = DiscoverNavigationPolicy.continueWatchingRoute(for: preview)
            return
        }

        resumingItemID = preview.continueWatchingRowID
        continueWatchingResumeTask?.cancel()
        continueWatchingResumeTask = Task { @MainActor in
            defer { resumingItemID = nil }
            if let request = await appState.resolveContinueWatchingSession(
                history: entry.history,
                preview: entry.preview
            ) {
                guard !Task.isCancelled else { return }
                // Another entry point may have claimed the player during the resolve await; rather
                // than dead-end, route through the detail page (which shows the "already playing"
                // toast or resumes once the slot frees).
                guard appState.activePlayerSession == nil else {
                    appState.discoverDetailRoute = DiscoverNavigationPolicy.continueWatchingRoute(for: preview)
                    return
                }
                // Honor the user's external-player preference before opening the embedded
                // player — same as Detail.openPlayer. Falls back to embedded if the external
                // app declines/isn't installed.
                let preference = await ExternalPlayerSettings.loadPreference(from: appState.settingsManager)
                if let launchURL = ExternalPlayerRouting.launchURL(for: request.stream.streamURL, preference: preference) {
                    let accepted = await withCheckedContinuation { continuation in
                        openURL(launchURL) { continuation.resume(returning: $0) }
                    }
                    if accepted { return }
                }
                appState.activePlayerSession = request
                openWindow(id: "player", value: request)
            } else {
                // No usable stored source — fall back to the normal search→resolve→play path.
                appState.discoverDetailRoute = DiscoverNavigationPolicy.continueWatchingRoute(for: preview)
            }
        }
    }
}

// MARK: - AI Curated Views

struct AICuratedHeroCard: View {
    let preview: MediaPreview
    let recommendation: AIMovieRecommendation
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            GeometryReader { proxy in
                aiBody(availableWidth: proxy.size.width)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 236)
            .clipShape(RoundedRectangle(cornerRadius: 22))
            .overlay {
                RoundedRectangle(cornerRadius: 22)
                    .strokeBorder(Color.white.opacity(0.12), lineWidth: 1)
            }
            .shadow(color: .black.opacity(0.16), radius: 20, y: 8)
        }
        .buttonStyle(.plain)
        #if os(visionOS)
        .hoverEffect(.lift)
        #endif
    }

    private func aiBody(availableWidth: CGFloat) -> some View {
        ZStack(alignment: .bottomLeading) {
            aiBackdropLayer
                .frame(maxWidth: .infinity)
                .frame(height: 236)
                .clipped()

            LinearGradient(
                stops: [
                    .init(color: .clear, location: 0.0),
                    .init(color: .black.opacity(0.2), location: 0.32),
                    .init(color: .black.opacity(0.78), location: 0.68),
                    .init(color: .black.opacity(0.96), location: 1.0),
                ],
                startPoint: .top,
                endPoint: .bottom
            )

            if showsAIPosterCard(availableWidth: availableWidth),
               let posterURL {
                aiPosterCard(url: posterURL)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .trailing)
                    .padding(.trailing, 24)
                    .accessibilityHidden(true)
            }

            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 8) {
                    GlassTag(text: "AI PICK", tintColor: .purple.opacity(0.24), symbol: "sparkles")

                    if let score = recommendation.score {
                        GlassTag(
                            text: String(format: "%.0f%% match", score * 100),
                            tintColor: .purple.opacity(0.18),
                            weight: .bold
                        )
                    }
                }

                Text(recommendation.title)
                    .font(.title2.weight(.bold))
                    .foregroundStyle(.white)
                    .lineLimit(2)

                HStack(spacing: 10) {
                    Text(recommendation.type.displayName.uppercased())
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.82))

                    if let year = recommendation.year {
                        Circle()
                            .fill(.white.opacity(0.4))
                            .frame(width: 4, height: 4)

                        Text(String(year))
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.74))
                    }

                    let ratingText = preview.ratingString
                    if !ratingText.isEmpty {
                        Circle()
                            .fill(.white.opacity(0.4))
                            .frame(width: 4, height: 4)

                        HStack(spacing: 3) {
                            Image(systemName: "star.fill")
                                .font(.system(size: 10))
                                .foregroundStyle(.white.opacity(0.85))
                            Text(ratingText)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.white.opacity(0.82))
                        }
                    }
                }

                Text(recommendation.reason)
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.84))
                    .lineLimit(3)

                HStack(spacing: 8) {
                    Image(systemName: "info.circle")
                        .font(.caption.weight(.semibold))
                    Text("Open details")
                        .font(.caption.weight(.semibold))
                }
                .foregroundStyle(.white.opacity(0.82))
            }
            .padding(.leading, 22)
            .padding(.trailing, aiContentTrailingPadding(availableWidth: availableWidth))
            .padding(.vertical, 22)
        }
    }

    private var heroArtworkKind: DiscoverHeroArtworkPresentationPolicy.HeroArtworkKind {
        DiscoverHeroArtworkPresentationPolicy.heroArtworkKind(
            backdropPath: preview.backdropPath,
            posterPath: preview.posterPath
        )
    }

    private var backdropURL: URL? {
        MediaArtworkURLPolicy.url(for: preview.backdropPath, legacyTMDBSizePath: "w1280")
    }

    private var posterURL: URL? {
        MediaArtworkURLPolicy.url(for: preview.posterPath, legacyTMDBSizePath: "w500")
    }

    private var aiArtworkLoadID: String {
        "\(preview.id)-ai-\(heroArtworkKind)-\(backdropURL?.absoluteString ?? posterURL?.absoluteString ?? "none")"
    }

    private func showsAIPosterCard(availableWidth: CGFloat) -> Bool {
        DiscoverHeroArtworkPresentationPolicy.showsPosterCard(for: heroArtworkKind) && availableWidth >= 520
    }

    private func aiContentTrailingPadding(availableWidth: CGFloat) -> CGFloat {
        guard showsAIPosterCard(availableWidth: availableWidth) else { return 22 }
        return min(146, max(22, availableWidth * 0.28))
    }

    @ViewBuilder
    private var aiBackdropLayer: some View {
        if heroArtworkKind == .backdrop, let backdropURL {
            AsyncImage(url: backdropURL) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                case .empty, .failure:
                    aiArtworkPlaceholder
                @unknown default:
                    aiArtworkPlaceholder
                }
            }
            .id(aiArtworkLoadID)
        } else {
            aiArtworkPlaceholder
        }
    }

    private var aiArtworkPlaceholder: some View {
        LinearGradient(
            colors: [
                Color(red: 0.12, green: 0.08, blue: 0.22),
                Color(red: 0.05, green: 0.04, blue: 0.09),
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    @ViewBuilder
    private func aiPosterCard(url: URL) -> some View {
        AsyncImage(url: url) { phase in
            switch phase {
            case .success(let image):
                image
                    .resizable()
                    .aspectRatio(2 / 3, contentMode: .fill)
                    .frame(
                        width: DiscoverHeroArtworkPresentationPolicy.aiPosterCardWidth,
                        height: DiscoverHeroArtworkPresentationPolicy.aiPosterCardHeight
                    )
                    .clipShape(aiPosterCardShape)
                    .overlay {
                        aiPosterCardShape
                            .strokeBorder(.white.opacity(0.20), lineWidth: 1)
                    }
                    .shadow(color: .black.opacity(0.34), radius: 16, y: 8)
            case .empty:
                aiPosterPlaceholder(showsIcon: false)
            case .failure:
                aiPosterPlaceholder(showsIcon: true)
            @unknown default:
                aiPosterPlaceholder(showsIcon: true)
            }
        }
        .id(aiArtworkLoadID)
        .allowsHitTesting(false)
    }

    private func aiPosterPlaceholder(showsIcon: Bool) -> some View {
        aiPosterCardShape
            .fill(.white.opacity(0.08))
            .frame(
                width: DiscoverHeroArtworkPresentationPolicy.aiPosterCardWidth,
                height: DiscoverHeroArtworkPresentationPolicy.aiPosterCardHeight
            )
            .overlay {
                aiPosterCardShape
                    .strokeBorder(.white.opacity(0.14), lineWidth: 1)
            }
            .overlay {
                if showsIcon {
                    Image(systemName: "photo")
                        .font(.callout.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.34))
                }
            }
            .shadow(color: .black.opacity(0.22), radius: 12, y: 6)
    }

    private var aiPosterCardShape: RoundedRectangle {
        RoundedRectangle(
            cornerRadius: DiscoverHeroArtworkPresentationPolicy.aiPosterCardCornerRadius,
            style: .continuous
        )
    }
}

struct AICuratedSupportingRow: View {
    let recommendation: AIMovieRecommendation
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        Text(recommendation.title)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.white)
                            .lineLimit(1)

                        if let score = recommendation.score {
                            GlassTag(
                                text: String(format: "%.0f%%", score * 100),
                                tintColor: .purple.opacity(0.18),
                                weight: .bold
                            )
                        }
                    }

                    HStack(spacing: 8) {
                        Text(recommendation.type.displayName)
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        if let year = recommendation.year {
                            Text("• \(year)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }

                    Text(recommendation.reason)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }

                Spacer(minLength: 12)

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.secondary)
                    .padding(.top, 6)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18))
            .glassStroke(cornerRadius: 18)
            .glassShadow()
        }
        .buttonStyle(.plain)
        #if os(visionOS)
        .hoverEffect(.highlight)
        #endif
    }
}

// MARK: - FeaturedHeroView

struct FeaturedHeroView: View {
    let item: MediaPreview
    let onTap: () -> Void
    @State private var isHovered = false

    var body: some View {
        GeometryReader { proxy in
            heroBody(availableWidth: proxy.size.width)
        }
        .frame(height: 540)
        .clipShape(RoundedRectangle(cornerRadius: 28))
        .overlay(
            RoundedRectangle(cornerRadius: 28)
                .strokeBorder(
                    LinearGradient(
                        colors: [
                            .white.opacity(isHovered ? 0.25 : 0.08),
                            .white.opacity(isHovered ? 0.06 : 0.01),
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
        .shadow(color: .black.opacity(0.07), radius: 24, y: 0)
        .shadow(color: .black.opacity(isHovered ? 0.35 : 0.13), radius: isHovered ? 18 : 8, x: 0, y: isHovered ? 10 : 4)
        .onHover { hovering in
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                isHovered = hovering
            }
        }
        #if os(visionOS)
        .hoverEffect(.lift)
        #endif
    }

    private func heroBody(availableWidth: CGFloat) -> some View {
        ZStack(alignment: .bottomLeading) {
            heroBackdropLayer
                .frame(height: 540)
                .clipped()

            // Cinematic gradient fade to dark at bottom
            LinearGradient(
                stops: [
                    .init(color: .clear, location: 0.0),
                    .init(color: .black.opacity(0.25), location: 0.35),
                    .init(color: .black.opacity(0.7), location: 0.65),
                    .init(color: .black.opacity(0.95), location: 1.0),
                ],
                startPoint: .top,
                endPoint: .bottom
            )

            if showsPosterCard(availableWidth: availableWidth),
               let posterURL {
                heroPosterCard(url: posterURL)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .trailing)
                    .padding(.trailing, 58)
                    .accessibilityHidden(true)
            }

            // Content overlay
            VStack(alignment: .leading, spacing: 14) {
                // Clean, confident title — the artwork carries the drama (Netflix/Apple TV style).
                Text(item.title)
                    .font(.system(size: 52, weight: .bold))
                    .foregroundStyle(.white)
                    .lineLimit(2)
                    .minimumScaleFactor(0.55)
                    .shadow(color: .black.opacity(0.6), radius: 12, y: 4)

                // Metadata row
                HStack(spacing: 12) {
                    Text(item.type.displayName.uppercased())
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundStyle(.white.opacity(0.8))

                    Circle()
                        .fill(.white.opacity(0.4))
                        .frame(width: 4, height: 4)

                    if let year = item.year {
                        Text(String(year))
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.7))
                    }

                    let ratingText = item.ratingString
                    if !ratingText.isEmpty {
                        Circle()
                            .fill(.white.opacity(0.4))
                            .frame(width: 4, height: 4)

                        HStack(spacing: 3) {
                            Text("IMDb")
                                .font(.caption2)
                                .foregroundStyle(.white.opacity(0.6))
                            Image(systemName: "star.fill")
                                .font(.system(size: 10))
                                .foregroundStyle(.white.opacity(0.85))
                            Text(ratingText)
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundStyle(.white.opacity(0.8))
                        }
                    }

                    // HDR — rendered as plain meta text (matches the row) rather than a lone glass pill.
                    Circle()
                        .fill(.white.opacity(0.4))
                        .frame(width: 4, height: 4)

                    Text("HDR")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundStyle(.white.opacity(0.8))
                }

                // Action buttons — Apple TV+ / Netflix language: solid light primary + glass secondary.
                HStack(spacing: 14) {
                    // Primary — solid white "Play"
                    Button(action: onTap) {
                        HStack(spacing: 9) {
                            Image(systemName: "play.fill")
                                .font(.system(size: 17, weight: .bold))
                            Text("Play")
                                .font(.system(size: 18, weight: .semibold))
                        }
                        .foregroundStyle(.black)
                        .padding(.horizontal, 30)
                        .padding(.vertical, 15)
                        .background(Capsule().fill(.white))
                        .shadow(color: .black.opacity(0.28), radius: 14, y: 5)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Play \(item.title)")
                    #if os(visionOS)
                    .hoverEffect(.lift)
                    #endif

                    // Secondary — glass "More Info"
                    Button(action: onTap) {
                        HStack(spacing: 8) {
                            Image(systemName: "info.circle")
                                .font(.system(size: 16, weight: .semibold))
                            Text("More Info")
                                .font(.system(size: 17, weight: .medium))
                        }
                        .foregroundStyle(.white)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 15)
                        .background(.ultraThinMaterial, in: Capsule())
                        .overlay {
                            Capsule().strokeBorder(
                                LinearGradient(
                                    colors: [.white.opacity(0.30), .white.opacity(0.08)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1
                            )
                        }
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("More info about \(item.title)")
                    #if os(visionOS)
                    .hoverEffect(.lift)
                    #endif
                }
                .padding(.top, 10)
            }
            .padding(.leading, 36)
            .padding(.trailing, contentTrailingPadding(availableWidth: availableWidth))
            .padding(.vertical, 36)
        }
    }

    private var heroArtworkKind: DiscoverHeroArtworkPresentationPolicy.HeroArtworkKind {
        DiscoverHeroArtworkPresentationPolicy.heroArtworkKind(
            backdropPath: item.backdropPath,
            posterPath: item.posterPath
        )
    }

    private var backdropURL: URL? {
        MediaArtworkURLPolicy.url(for: item.backdropPath, legacyTMDBSizePath: "w1280")
    }

    private var posterURL: URL? {
        MediaArtworkURLPolicy.url(for: item.posterPath, legacyTMDBSizePath: "w500")
    }

    private var heroArtworkLoadID: String {
        "\(item.id)-\(heroArtworkKind)-\(backdropURL?.absoluteString ?? posterURL?.absoluteString ?? "none")"
    }

    private func showsPosterCard(availableWidth: CGFloat) -> Bool {
        DiscoverHeroArtworkPresentationPolicy.showsPosterCard(for: heroArtworkKind) && availableWidth >= 760
    }

    private func contentTrailingPadding(availableWidth: CGFloat) -> CGFloat {
        guard showsPosterCard(availableWidth: availableWidth) else { return 36 }
        return min(280, max(36, availableWidth * 0.34))
    }

    @ViewBuilder
    private var heroBackdropLayer: some View {
        if heroArtworkKind == .backdrop, let backdropURL {
            // Using a stable artwork id prevents stale hero art when metadata changes in place.
            AsyncImage(url: backdropURL, transaction: Transaction(animation: .easeOut(duration: 0.45))) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .aspectRatio(16 / 9, contentMode: .fill)
                        .scaleEffect(isHovered ? 1.04 : 1.0)
                        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: isHovered)
                        .transition(.opacity)
                case .empty, .failure:
                    heroArtworkPlaceholder
                @unknown default:
                    heroArtworkPlaceholder
                }
            }
            .id(heroArtworkLoadID)
        } else {
            heroArtworkPlaceholder
        }
    }

    private var heroArtworkPlaceholder: some View {
        Rectangle().fill(
            LinearGradient(
                colors: [
                    Color(red: 0.08, green: 0.06, blue: 0.14),
                    Color(red: 0.04, green: 0.03, blue: 0.08),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
    }

    @ViewBuilder
    private func heroPosterCard(url: URL) -> some View {
        AsyncImage(url: url, transaction: Transaction(animation: .easeOut(duration: 0.35))) { phase in
            switch phase {
            case .success(let image):
                image
                    .resizable()
                    .aspectRatio(2 / 3, contentMode: .fill)
                    .frame(
                        width: DiscoverHeroArtworkPresentationPolicy.posterCardWidth,
                        height: DiscoverHeroArtworkPresentationPolicy.posterCardHeight
                    )
                    .clipShape(heroPosterCardShape)
                    .overlay {
                        heroPosterCardShape
                            .strokeBorder(.white.opacity(0.20), lineWidth: 1)
                    }
                    .shadow(color: .black.opacity(0.42), radius: 26, y: 14)
                    .transition(.opacity)
            case .empty:
                heroPosterPlaceholder(showsIcon: false)
            case .failure:
                heroPosterPlaceholder(showsIcon: true)
            @unknown default:
                heroPosterPlaceholder(showsIcon: true)
            }
        }
        .id(heroArtworkLoadID)
        .allowsHitTesting(false)
    }

    private func heroPosterPlaceholder(showsIcon: Bool) -> some View {
        heroPosterCardShape
            .fill(.white.opacity(0.08))
            .frame(
                width: DiscoverHeroArtworkPresentationPolicy.posterCardWidth,
                height: DiscoverHeroArtworkPresentationPolicy.posterCardHeight
            )
            .overlay {
                heroPosterCardShape
                    .strokeBorder(.white.opacity(0.14), lineWidth: 1)
            }
            .overlay {
                if showsIcon {
                    Image(systemName: "photo")
                        .font(.title2.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.34))
                }
            }
            .shadow(color: .black.opacity(0.24), radius: 18, y: 10)
    }

    private var heroPosterCardShape: RoundedRectangle {
        RoundedRectangle(
            cornerRadius: DiscoverHeroArtworkPresentationPolicy.posterCardCornerRadius,
            style: .continuous
        )
    }
}

// MARK: - MediaRow

enum MediaRowScrollCuePolicy {
    static let trailingFadeStart = 0.98
    static let trailingFadeEnd = 1.0
}

struct MediaRow: View {
    let title: String
    var symbol: String = ""
    let items: [MediaPreview]
    var userRatings: [String: TasteEvent] = [:]
    var animationDelay: Double = 0
    /// Continue Watching only: per-item watch progress (0...1) and last-frame artwork, plus the
    /// item currently resolving a direct resume. Empty/nil for normal browse rows.
    var progressByItemID: [String: Double] = [:]
    var lastFrameByItemID: [String: URL] = [:]
    var resumingItemID: String? = nil
    let onSelect: (MediaPreview) -> Void

    @AppStorage(VPDesignFlags.useObsidianGlassKey) private var useObsidianGlass = true
    @State private var appeared = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Section header
            if useObsidianGlass {
                // Clean, confident section header — the artwork carries the weight, not chrome.
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(title)
                        .font(.system(size: 23, weight: .bold))
                        .foregroundStyle(VPColor.textPrimary)

                    Spacer(minLength: 0)

                    // Scroll cue: signals the row continues past the right edge.
                    // Non-interactive on purpose — there is no dedicated "See All"
                    // destination yet, so this must not read or behave as a tappable control.
                    HStack(spacing: 3) {
                        Text("See All")
                            .font(.subheadline.weight(.semibold))
                        Image(systemName: "chevron.right")
                            .font(.system(size: 12, weight: .semibold))
                    }
                    .foregroundStyle(VPColor.textSecondary)
                    .accessibilityHidden(true)
                }
                .padding(.horizontal, 12)
                .accessibilityAddTraits(.isHeader)
            } else {
                HStack(spacing: 8) {
                    if !symbol.isEmpty {
                        Image(systemName: symbol)
                            .font(.headline)
                            .foregroundStyle(.secondary)
                    }
                    Text(title)
                        .font(.headline)
                        .foregroundStyle(.white)
                }
                .padding(.horizontal, 8)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 12) {
                    ForEach(items, id: \.continueWatchingRowID) { item in
                        Button { onSelect(item) } label: {
                            MediaCardView(
                                item: item,
                                userRating: TasteRatingLookupPolicy.rating(
                                    in: userRatings,
                                    mediaId: item.id,
                                    type: item.type,
                                    tmdbId: item.tmdbId
                                ),
                                progressPercent: progressByItemID[item.continueWatchingRowID],
                                lastFrameURL: lastFrameByItemID[item.continueWatchingRowID],
                                isResuming: resumingItemID == item.continueWatchingRowID
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 8)
            }
            // Right-edge fade so the trailing tile dissolves into the background instead of
            // hard-clipping, reinforcing that the row scrolls horizontally.
            .mask(
                LinearGradient(
                    stops: [
                        .init(color: .black, location: 0.0),
                        .init(color: .black, location: MediaRowScrollCuePolicy.trailingFadeStart),
                        .init(color: .clear, location: MediaRowScrollCuePolicy.trailingFadeEnd),
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
        }
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 18)
        .onAppear {
            withAnimation(.spring(response: 0.55, dampingFraction: 0.82).delay(animationDelay)) {
                appeared = true
            }
        }
    }
}
