import SwiftUI
import os

private enum SeriesDetailQAScrollDebug {
    private static let logger = Logger(subsystem: "com.vpstudio", category: "series-detail-scroll")

    static func log(_ message: @autoclosure () -> String) {
        guard QARuntimeOptions.scrollDebug else { return }
        let renderedMessage = message()
        logger.debug("\(renderedMessage, privacy: .public)")
    }
}

enum DetailHeroArtworkPresentationPolicy {
    enum HeroArtworkKind: Equatable {
        case backdrop
        case posterOnly
        case none
    }

    static let posterCardWidth: CGFloat = 132
    static let posterCardHeight: CGFloat = 198
    static let posterCardCornerRadius: CGFloat = 14

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

enum SeriesPrimaryPlayPolicy {
    static let noStreamsMessage = "No streams found for this episode. Try another episode or result."
    static let selectEpisodeLabel = "Select Episode"

    static func isBusy(
        isLocalPlayLoading: Bool,
        isPlayerOpening: Bool,
        isLoadingSeasonEpisodes: Bool
    ) -> Bool {
        isLocalPlayLoading || isPlayerOpening || isLoadingSeasonEpisodes
    }

    static func isEnabled(
        mediaType: MediaType,
        hasSelectedEpisode: Bool,
        isBusy: Bool
    ) -> Bool {
        guard !isBusy else { return false }
        return mediaType != .series || hasSelectedEpisode
    }

    static func title(
        mediaType: MediaType,
        hasSelectedEpisode: Bool
    ) -> String {
        mediaType == .series && !hasSelectedEpisode ? selectEpisodeLabel : "Play"
    }

    static func accessibilityHint(
        mediaType: MediaType,
        hasSelectedEpisode: Bool
    ) -> String {
        if mediaType == .series && !hasSelectedEpisode {
            return "Moves to episode choices before loading streams."
        }
        return "Searches for streams if needed and opens the first available result."
    }
}

enum SeriesDetailScrollPolicy {
    static func shouldShowTorrentsSection(
        mediaType: MediaType,
        hasSelectedEpisode: Bool,
        isLoadingTorrentSearch: Bool,
        didSearch: Bool,
        hasTorrentResults: Bool
    ) -> Bool {
        if mediaType == .series {
            return hasSelectedEpisode || isLoadingTorrentSearch || didSearch || hasTorrentResults
        }

        return isLoadingTorrentSearch || didSearch || hasTorrentResults
    }

    static func shouldScrollToResults(
        tappedEpisodeID: String,
        currentSelectedEpisodeID: String?,
        isTaskCancelled: Bool
    ) -> Bool {
        // Auto-scrolling to the bottom streams block on episode selection
        // proved visually unstable in the live series detail route.
        let _ = tappedEpisodeID
        let _ = currentSelectedEpisodeID
        let _ = isTaskCancelled
        return false
    }
}

enum SeriesSeasonLoadingPresentationPolicy {
    static func shouldShowEpisodesSection(
        hasSeasons: Bool,
        episodeCount: Int,
        isLoadingSeasonEpisodes: Bool
    ) -> Bool {
        hasSeasons && (episodeCount > 0 || isLoadingSeasonEpisodes)
    }

    static func loadingTitle(for seasonNumber: Int) -> String {
        "Loading Season \(seasonNumber)…"
    }

    static func loadingMessage(for seasonNumber: Int) -> String {
        "Updating episode choices for Season \(seasonNumber) while keeping your place on the page."
    }
}

enum SeriesDetailPresentationPolicy {
    static let heroHeight: CGFloat = 244
    static let overviewMaxWidth: CGFloat = 760
    static let overviewLineLimit = 3
    static let bottomContentPadding: CGFloat = 168
    static let bottomViewportInset: CGFloat = 128
    static let contentSpacing: CGFloat = 18
    static let contentTopPadding: CGFloat = 18
    static let episodesSectionSpacing: CGFloat = 14
    static let episodesSectionTopPadding: CGFloat = 12
    static let episodeCardWidth: CGFloat = 220
    static let episodeCardHeight: CGFloat = 124
    static let postEpisodeExtrasTopPadding: CGFloat = VPSpace.roomy

    static func seasonCountText(_ count: Int) -> String? {
        guard count > 0 else { return nil }
        return "\(count) Season\(count == 1 ? "" : "s")"
    }

    static func runtimeText(minutes: Int?) -> String? {
        guard let minutes, minutes > 0 else { return nil }
        return "\(minutes) min"
    }

    static func imdbRatingText(_ rating: Double?) -> String? {
        let text = MediaRatingPolicy.displayText(rating)
        return text.isEmpty ? nil : "\(text) IMDb"
    }

    static func episodeContextText(season: Int, episodeNumber: Int) -> String {
        "S\(season):E\(episodeNumber)"
    }

    static func episodeRuntimeText(minutes: Int?) -> String? {
        guard let minutes, minutes > 0 else { return nil }
        return "• \(minutes)m"
    }

    static func episodeTitle(_ title: String?, episodeNumber: Int) -> String {
        guard let title, !title.isEmpty else { return "Episode \(episodeNumber)" }
        return title
    }

    static func episodeAccessibilityLabel(episodeNumber: Int, title: String?) -> String {
        "Episode \(episodeNumber), \(title ?? "Untitled")"
    }

    static func episodeAccessibilityValue(isWatched: Bool, isSelected: Bool) -> String {
        switch (isWatched, isSelected) {
        case (true, true):
            return "Watched, selected"
        case (true, false):
            return "Watched"
        case (false, true):
            return "Selected"
        case (false, false):
            return "Not watched"
        }
    }

    static func episodeWatchLabel(isWatched: Bool) -> String {
        isWatched ? "Watched" : "Not watched"
    }

    static func episodeWatchActionTitle(isWatched: Bool) -> String {
        isWatched ? "Mark Episode as Unwatched" : "Mark Episode as Watched"
    }

    static func watchStatusIcon(for state: DetailWatchStatusState) -> String {
        switch state {
        case .watched:
            return "checkmark.circle.fill"
        case .inProgress:
            return "play.circle.fill"
        case .notWatched:
            return "circle"
        case .selectionRequired:
            return "rectangle.and.hand.point.up.left.fill"
        }
    }

    static func selectedEpisodeWatchState(hasSelectedEpisode: Bool, isSelectedEpisodeCompleted: Bool) -> DetailWatchStatusState {
        guard hasSelectedEpisode else { return .selectionRequired }
        return isSelectedEpisodeCompleted ? .watched : .notWatched
    }

    static func seriesWatchProgressLabel(watchedCount: Int, seasonEpisodeCounts: [Int]) -> String {
        let totalCount = max(seasonEpisodeCounts.reduce(0, +), watchedCount)
        guard totalCount > 0 else { return "Series Actions" }
        return "\(watchedCount)/\(totalCount) watched"
    }
}

/// Copy + glyph for the user-facing RATE action (the control that opens the rating sheet).
///
/// This is the *interactive* rating affordance — distinct from the read-only IMDb display mark
/// rendered elsewhere in the metadata row. It carries a visible "Rate" / current-score text label
/// so it no longer reads as one of N identical monochrome chrome glyphs.
enum SeriesRateControlPolicy {
    /// Visible label beside the star glyph. When the user has not rated yet, prompt with "Rate".
    /// Once a rating exists, surface the formatted summary as-is (e.g. "8/10", "Liked") so the
    /// control reads as both the current value and the way to edit it — across every scale mode
    /// (like/dislike, 1-10, 1-100), where a hard-coded "Rated N" prefix would read awkwardly.
    static func visibleLabel(currentFeedbackSummary: String?) -> String {
        guard let summary = currentFeedbackSummary, !summary.isEmpty else { return "Rate" }
        return summary
    }

    /// SF Symbol for the rate control: a filled star once a rating exists, an outline otherwise.
    static func glyphName(hasRating: Bool) -> String {
        hasRating ? "star.fill" : "star"
    }
}

/// A series‑detail layout matching the reference screenshot exactly:
/// – Back arrow top-left, share/list/cast icons top-right
/// – Hero image with gradient overlay
/// – Title "SHRINKING" large and bold
/// – Metadata row: year, season count, IMDb rating, favorite heart
/// – Large white play button
/// – Current episode info: "S3:E4 The Final Chapter • 35m"
/// – Synopsis paragraph
/// – Season tabs as circular numbers (1, 2, 3) with selected state
/// – Horizontal episode grid with thumbnails, progress bars, checkmarks
struct SeriesDetailLayout: View {
    let viewModel: DetailViewModel
    let title: String
    let metadataConfiguration: MetadataProviderConfiguration
    let mediaType: MediaType
    let streamResultsAnchor: String
    let shareItem: String
    @Binding var isPlayerOpening: Bool
    @Binding var playerOpeningError: String?
    /// Which torrent row triggered the in-progress play, so its inline feedback is scoped to that
    /// row. `nil` (the default / non-row plays) falls back to the shared broadcast behaviour.
    var openingTorrentID: TorrentResult.ID?
    let onPlayTorrent: (TorrentResult) -> Void
    let onCast: () -> Void
    let onShowRatingSheet: () -> Void
    
    @Environment(\.dismiss) private var dismiss
    @State private var isPlayButtonLoading = false
    @State private var episodeScrollRequest = 0
    @State private var heroOverlayFrame: CGRect = .zero

    private let episodesSectionID = "episodes-section"

    private var isPrimaryPlayBusy: Bool {
        SeriesPrimaryPlayPolicy.isBusy(
            isLocalPlayLoading: isPlayButtonLoading,
            isPlayerOpening: isPlayerOpening,
            isLoadingSeasonEpisodes: viewModel.isLoading(.seasonEpisodes)
        )
    }

    private var isPrimaryPlayEnabled: Bool {
        SeriesPrimaryPlayPolicy.isEnabled(
            mediaType: mediaType,
            hasSelectedEpisode: viewModel.selectedEpisode != nil,
            isBusy: isPrimaryPlayBusy
        )
    }

    private var shouldShowTorrentsSection: Bool {
        SeriesDetailScrollPolicy.shouldShowTorrentsSection(
            mediaType: mediaType,
            hasSelectedEpisode: viewModel.selectedEpisode != nil,
            isLoadingTorrentSearch: viewModel.isLoading(.torrentSearch),
            didSearch: viewModel.torrentSearch.didSearch,
            hasTorrentResults: !viewModel.torrentSearch.results.isEmpty
        )
    }

    private var shouldShowEpisodesSection: Bool {
        SeriesSeasonLoadingPresentationPolicy.shouldShowEpisodesSection(
            hasSeasons: !viewModel.seasons.isEmpty,
            episodeCount: viewModel.episodes.count,
            isLoadingSeasonEpisodes: viewModel.isLoading(.seasonEpisodes)
        )
    }

    var body: some View {
        ScrollViewReader { scrollProxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    // MARK: - Hero Image
                    heroImage
                        // Bias the fill toward the top so character heads clip less than a
                        // centered crop would.
                        .frame(height: SeriesDetailPresentationPolicy.heroHeight, alignment: .top)
                        .clipped()
                        .overlay(heroOverlay)

                    // MARK: - Main Content
                    VStack(alignment: .leading, spacing: SeriesDetailPresentationPolicy.contentSpacing) {
                        // Title now lives on the hero artwork (see heroOverlay).
                        // Metadata row
                        metadataRow

                        // Play button
                        playButtonRow

                        if mediaType != .series {
                            watchStateRow
                        }

                        // Current episode info
                        currentEpisodeRow

                        // Only surface the press-and-hold hint when episodes are actually
                        // shown below, so the tip sits near what it describes.
                        if mediaType == .series, shouldShowEpisodesSection {
                            seriesTrackingRow
                        }

                        // Synopsis
                        if let overview = viewModel.mediaItem?.overview, !overview.isEmpty {
                            Text(overview)
                                .font(.body)
                                .foregroundStyle(.white.opacity(0.85))
                                .lineLimit(SeriesDetailPresentationPolicy.overviewLineLimit)
                                .frame(
                                    maxWidth: SeriesDetailPresentationPolicy.overviewMaxWidth,
                                    alignment: .leading
                                )
                                .padding(.top, 4)
                        }

                        if mediaType != .series {
                            DetailAIAnalysis(viewModel: viewModel)
                                .padding(.top, 16)

                            if let genres = viewModel.mediaItem?.genres, !genres.isEmpty {
                                genrePills(genres)
                            }
                        }

                        if let status = viewModel.libraryStatusMessage {
                            Text(status)
                                .font(.caption)
                                .foregroundStyle(.white.opacity(0.68))
                        }

                        // Seasons
                        if !viewModel.seasons.isEmpty {
                            seasonsSection
                        }

                        // Episodes
                        if shouldShowEpisodesSection {
                            episodesSection()
                                .id(episodesSectionID)
                        }

                        if mediaType == .series {
                            DetailAIAnalysis(viewModel: viewModel)
                                .padding(.top, SeriesDetailPresentationPolicy.postEpisodeExtrasTopPadding)

                            if let genres = viewModel.mediaItem?.genres, !genres.isEmpty {
                                genrePills(genres)
                            }
                        }

                        // Torrents
                        if shouldShowTorrentsSection {
                            torrentsSection
                        }

                        Spacer(minLength: SeriesDetailPresentationPolicy.bottomContentPadding)
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, SeriesDetailPresentationPolicy.contentTopPadding)
                }
            }
            .onChange(of: episodeScrollRequest) { _, _ in
                guard shouldShowEpisodesSection else { return }
                withAnimation(.easeInOut(duration: 0.3)) {
                    scrollProxy.scrollTo(episodesSectionID, anchor: .top)
                }
            }
            .defaultScrollAnchor(QARuntimeOptions.scrollAnchorBottom ? .bottom : .top)
        }
        .background(Color.black)
        .safeAreaInset(edge: .bottom) {
            VPBottomViewportScrim(height: SeriesDetailPresentationPolicy.bottomViewportInset)
        }
        .foregroundStyle(.white)
        #if !os(macOS)
        .toolbar(.hidden, for: .navigationBar)
        #endif
        .onAppear {
            SeriesDetailQAScrollDebug.log(
                "appear title=\(title) mediaType=\(mediaType.rawValue) selectedEpisode=\(viewModel.selectedEpisode?.id ?? "nil") didSearch=\(viewModel.torrentSearch.didSearch) results=\(viewModel.torrentSearch.results.count)"
            )
        }
        .onChange(of: viewModel.selectedEpisode?.id) { _, newValue in
            SeriesDetailQAScrollDebug.log("selectedEpisode=\(newValue ?? "nil")")
        }
        .onChange(of: viewModel.episodes.count) { _, newValue in
            SeriesDetailQAScrollDebug.log(
                "episodesCount=\(newValue) seasons=\(viewModel.seasons.count) showEpisodesSection=\(shouldShowEpisodesSection)"
            )
        }
        .onChange(of: viewModel.torrentSearch.results.count) { _, newValue in
            SeriesDetailQAScrollDebug.log("torrentResults=\(newValue)")
        }
        .onChange(of: viewModel.torrentSearch.didSearch) { _, newValue in
            SeriesDetailQAScrollDebug.log("didSearch=\(newValue)")
        }
        .onChange(of: viewModel.loadingPhase?.rawValue ?? "none") { _, newValue in
            SeriesDetailQAScrollDebug.log("loadingPhase=\(newValue)")
        }
    }
    
    // MARK: - Subviews
    
    private var heroImage: some View {
        Group {
            if detailHeroArtworkKind == .backdrop, let detailHeroBackdropURL {
                AsyncImage(url: detailHeroBackdropURL) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    case .empty, .failure:
                        detailHeroPlaceholder
                    @unknown default:
                        detailHeroPlaceholder
                    }
                }
                .id(detailHeroArtworkLoadID)
            } else {
                detailHeroPlaceholder
            }
        }
    }

    private var detailHeroArtworkKind: DetailHeroArtworkPresentationPolicy.HeroArtworkKind {
        DetailHeroArtworkPresentationPolicy.heroArtworkKind(
            backdropPath: viewModel.mediaItem?.backdropPath,
            posterPath: viewModel.mediaItem?.posterPath
        )
    }

    private var detailHeroBackdropURL: URL? {
        MediaArtworkURLPolicy.url(for: viewModel.mediaItem?.backdropPath, legacyTMDBSizePath: "w1280")
    }

    private var detailHeroPosterURL: URL? {
        MediaArtworkURLPolicy.url(for: viewModel.mediaItem?.posterPath, legacyTMDBSizePath: "w500")
    }

    private var detailHeroArtworkLoadID: String {
        let mediaID = viewModel.mediaItem?.id ?? "none"
        return "\(mediaID)-detail-\(detailHeroArtworkKind)-\(detailHeroBackdropURL?.absoluteString ?? detailHeroPosterURL?.absoluteString ?? "none")"
    }

    private var detailHeroPlaceholder: some View {
        Rectangle()
            .fill(
                LinearGradient(
                    colors: [.gray.opacity(0.3), .gray.opacity(0.1)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
    }
    
    private var heroOverlay: some View {
        // Reads the overlay width without a GeometryReader container: GeometryReader
        // inside the detail ScrollView triggers repeated layout measurement passes
        // and scroll thrashing. `onGeometryChange` captures the width into state and
        // only re-runs the body when the measured width actually changes. The local
        // `proxy` snapshot keeps the measured-geometry spelling at the call site.
        let proxy = heroOverlayFrame
        return heroOverlayBody(availableWidth: proxy.size.width)
            .onGeometryChange(for: CGFloat.self) { geometry in
                geometry.size.width
            } action: { newWidth in
                heroOverlayFrame.size.width = newWidth
            }
    }

    private func heroOverlayBody(availableWidth: CGFloat) -> some View {
        ZStack(alignment: .top) {
            // Cinematic scrim: subtle darkening up top for the back/utility controls,
            // strong fade to near-black at the bottom so the title reads on the artwork.
            LinearGradient(
                stops: [
                    .init(color: .black.opacity(0.52), location: 0.0),
                    .init(color: .black.opacity(0.16), location: 0.26),
                    .init(color: .black.opacity(0.68), location: 0.58),
                    .init(color: .black.opacity(0.88), location: 0.78),
                    .init(color: .black.opacity(0.98), location: 1.0),
                ],
                startPoint: .top,
                endPoint: .bottom
            )

            if showsDetailHeroPosterCard(availableWidth: availableWidth),
               let detailHeroPosterURL {
                detailHeroPosterCard(url: detailHeroPosterURL)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .trailing)
                    .padding(.trailing, 32)
                    .accessibilityHidden(true)
            }

            // Title overlaid on the bottom of the artwork (Apple TV+ / Netflix pattern).
            VStack(spacing: 0) {
                Spacer(minLength: 0)
                HStack {
                    Text(title.uppercased())
                        .font(.system(size: 56, weight: .heavy))
                        .foregroundStyle(.white)
                        .lineLimit(2)
                        .minimumScaleFactor(0.6)
                        .shadow(color: .black.opacity(0.6), radius: 10, y: 4)
                        .accessibilityAddTraits(.isHeader)
                    Spacer(minLength: 0)
                }
                .padding(.leading, 24)
                .padding(.trailing, detailHeroTitleTrailingPadding(availableWidth: availableWidth))
                .padding(.bottom, 18)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            // Top bar
            HStack {
                // Back button
                Button(action: { dismiss() }) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 20, weight: .semibold))
                        .frame(width: 44, height: 44)
                        .background(.ultraThinMaterial, in: Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Back")
                .accessibilityHint("Returns to the previous screen.")
                
                Spacer()
                
                // Utility icons
                HStack(spacing: 12) {
                    ShareLink(item: shareItem) {
                        utilityGlyph(name: "square.and.arrow.up")
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Share title")
                    .accessibilityHint("Opens the share sheet for this title.")

                    // (Watchlist toggle intentionally lives only on the labeled play-row
                    // "Watchlist" button below — the duplicate top-bar bookmark was removed.)
                    Button(action: onCast) {
                        utilityGlyph(name: "airplayvideo")
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Cast")
                    .accessibilityHint("Opens playback destination options.")

                    // NOTE: the RATE action no longer lives in this chrome cluster. It was an
                    // unlabeled monochrome star here — indistinguishable from the share/cast/AI
                    // glyphs and easily confused with the read-only gold IMDb mark below. It now
                    // renders as a clearly-labeled "Rate" pill in the metadata row (see rateControl).

                    // AI button — glass to match the utility cluster, purple glyph keeps the AI brand
                    Button {
                        Task { await viewModel.fetchAIAnalysis() }
                    } label: {
                        Image(systemName: "brain")
                            .font(.system(size: 18))
                            .foregroundStyle(.purple)
                            .frame(width: 44, height: 44)
                            .background(.ultraThinMaterial, in: Circle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Analyze with AI")
                    .accessibilityHint("Requests an AI summary for this title.")
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
        }
    }

    private func showsDetailHeroPosterCard(availableWidth: CGFloat) -> Bool {
        DetailHeroArtworkPresentationPolicy.showsPosterCard(for: detailHeroArtworkKind) && availableWidth >= 680
    }

    private func detailHeroTitleTrailingPadding(availableWidth: CGFloat) -> CGFloat {
        guard showsDetailHeroPosterCard(availableWidth: availableWidth) else { return 24 }
        return min(204, max(24, availableWidth * 0.30))
    }

    @ViewBuilder
    private func detailHeroPosterCard(url: URL) -> some View {
        AsyncImage(url: url) { phase in
            switch phase {
            case .success(let image):
                image
                    .resizable()
                    .aspectRatio(2 / 3, contentMode: .fill)
                    .frame(
                        width: DetailHeroArtworkPresentationPolicy.posterCardWidth,
                        height: DetailHeroArtworkPresentationPolicy.posterCardHeight
                    )
                    .clipShape(detailHeroPosterCardShape)
                    .overlay {
                        detailHeroPosterCardShape
                            .strokeBorder(.white.opacity(0.20), lineWidth: 1)
                    }
                    .shadow(color: .black.opacity(0.38), radius: 18, y: 10)
            case .empty:
                detailHeroPosterPlaceholder(showsIcon: false)
            case .failure:
                detailHeroPosterPlaceholder(showsIcon: true)
            @unknown default:
                detailHeroPosterPlaceholder(showsIcon: true)
            }
        }
        .id(detailHeroArtworkLoadID)
        .allowsHitTesting(false)
    }

    private func detailHeroPosterPlaceholder(showsIcon: Bool) -> some View {
        detailHeroPosterCardShape
            .fill(.white.opacity(0.08))
            .frame(
                width: DetailHeroArtworkPresentationPolicy.posterCardWidth,
                height: DetailHeroArtworkPresentationPolicy.posterCardHeight
            )
            .overlay {
                detailHeroPosterCardShape
                    .strokeBorder(.white.opacity(0.14), lineWidth: 1)
            }
            .overlay {
                if showsIcon {
                    Image(systemName: "photo")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.34))
                }
            }
            .shadow(color: .black.opacity(0.24), radius: 14, y: 8)
    }

    private var detailHeroPosterCardShape: RoundedRectangle {
        RoundedRectangle(
            cornerRadius: DetailHeroArtworkPresentationPolicy.posterCardCornerRadius,
            style: .continuous
        )
    }
    
    private var metadataRow: some View {
        HStack(spacing: 16) {
            // Year/season/runtime are secondary context — de-emphasize so the rating reads
            // as the primary signal in this row.
            if let year = viewModel.mediaItem?.year {
                Text(String(year))
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.76))
            }

            if mediaType == .series, !viewModel.seasons.isEmpty {
                // Series: show seasons + episode count, not a single (misleading) runtime.
                Text(SeriesDetailPresentationPolicy.seasonCountText(viewModel.seasons.count) ?? "")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.76))

                let episodeTotal = viewModel.seasons.reduce(0) { $0 + $1.episodeCount }
                if episodeTotal > 0 {
                    Text("\(episodeTotal) Episodes")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.76))
                }
            } else if let runtimeText = SeriesDetailPresentationPolicy.runtimeText(minutes: viewModel.mediaItem?.runtime) {
                Text(runtimeText)
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.76))
            }

            if let ratingText = SeriesDetailPresentationPolicy.imdbRatingText(viewModel.mediaItem?.imdbRating) {
                // Read-only IMDb score DISPLAY (not the rate control). Combined into a single
                // static accessibility element labeled as a rating so VoiceOver users don't
                // mistake the gold star for the interactive "Rate" action (see rateControl).
                HStack(spacing: 4) {
                    // Small gold accent, not a loud badge — shrink to caption2 so it reads
                    // as a subtle mark beside the weighted rating value.
                    Image(systemName: "star.fill")
                        .font(.caption2)
                        .foregroundStyle(.yellow)
                    Text(ratingText)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("IMDb rating \(ratingText)")
            }

            // Separate the favorite affordance from the rating group so the heart no longer
            // visually attaches to the IMDb mark.
            Spacer(minLength: 0)

            // Rate control — the interactive rating action, with a visible "Rate" / current-score
            // text label so it reads as the way to rate this title (not a bare chrome glyph,
            // and not the read-only gold IMDb mark on the leading edge of this row).
            rateControl

            // Favorite button
            Button {
                Task { await viewModel.toggleFavorites() }
            } label: {
                Image(systemName: viewModel.mediaLibrary.isInFavorites ? "heart.fill" : "heart")
                    .font(.system(size: 16))
                    .foregroundStyle(viewModel.mediaLibrary.isInFavorites ? .red : .white.opacity(0.85))
                    .frame(width: 32, height: 32)
                    .background(.ultraThinMaterial, in: Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(viewModel.mediaLibrary.isInFavorites ? "Remove from Favorites" : "Add to Favorites")
            .accessibilityHint("Toggles this title in your Favorites list.")
        }
    }

    /// The interactive RATE affordance: a labeled pill (star glyph + "Rate" / current-score text)
    /// that opens the rating sheet. Distinct treatment + visible copy keep it from being mistaken
    /// for the read-only IMDb display mark or for one of the monochrome top-bar chrome glyphs.
    private var rateControl: some View {
        let hasRating = viewModel.currentFeedbackValue != nil
        return Button(action: onShowRatingSheet) {
            HStack(spacing: 6) {
                Image(systemName: SeriesRateControlPolicy.glyphName(hasRating: hasRating))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(hasRating ? VPColor.accent : .white.opacity(0.9))
                Text(SeriesRateControlPolicy.visibleLabel(currentFeedbackSummary: viewModel.currentFeedbackSummary))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.92))
            }
            .padding(.horizontal, 12)
            .frame(minHeight: 32)
            .background(.ultraThinMaterial, in: Capsule())
            .overlay(
                Capsule().strokeBorder(VPColor.accent.opacity(hasRating ? 0.55 : 0.30), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(viewModel.currentFeedbackValue != nil ? "Edit rating" : "Rate title")
        .accessibilityHint("Opens rating controls for this title.")
    }
    
    private var playButtonRow: some View {
        // Primary play paired with a secondary glass action so the white pill no longer
        // reads as a lone full-width web-form button.
        HStack(spacing: 12) {
            Button {
                if mediaType == .series, viewModel.selectedEpisode == nil {
                    episodeScrollRequest += 1
                    return
                }

                guard isPrimaryPlayEnabled else { return }
                playerOpeningError = nil
                isPlayButtonLoading = true
                Task {
                    defer { isPlayButtonLoading = false }

                    // Ensure we have torrents for the selected episode
                    if viewModel.torrentSearch.results.isEmpty {
                        await viewModel.searchTorrents()
                    }

                    guard let torrent = viewModel.torrentSearch.results.first else {
                        playerOpeningError = SeriesPrimaryPlayPolicy.noStreamsMessage
                        return
                    }

                    onPlayTorrent(torrent)
                }
            } label: {
                HStack(spacing: 12) {
                    if isPrimaryPlayBusy {
                        // Spinner is tinted to match the white pill's near-black glyph.
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: VPColor.void))
                    } else {
                        // Icon tracks the label: a stack glyph for the "Select Episode" state,
                        // a play glyph only when the button actually starts playback.
                        let needsEpisodeSelection = mediaType == .series && viewModel.selectedEpisode == nil
                        Image(systemName: needsEpisodeSelection ? "rectangle.stack" : "play.fill")
                            .font(.system(size: 22))
                        Text(
                            SeriesPrimaryPlayPolicy.title(
                                mediaType: mediaType,
                                hasSelectedEpisode: viewModel.selectedEpisode != nil
                            )
                        )
                            .font(.headline)
                    }
                }
                // Fixed-width pill instead of full-bleed so it reads as a focused CTA;
                // VPButtonStyle(.primary) supplies the white fill, VPColor.void glyph,
                // VPRadius.control corner, 60pt min height, pressed scale, and 0.45
                // disabled opacity (the canonical WHITE-primary hero look).
                .frame(width: 220)
            }
            .buttonStyle(VPButtonStyle(kind: .primary))
            .disabled(isPrimaryPlayBusy)
            .accessibilityHint(
                SeriesPrimaryPlayPolicy.accessibilityHint(
                    mediaType: mediaType,
                    hasSelectedEpisode: viewModel.selectedEpisode != nil
                )
            )

            // Secondary watchlist action in glass to balance the primary CTA.
            Button {
                Task { await viewModel.toggleWatchlist() }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: viewModel.isInWatchlist ? "checkmark" : "plus")
                        .font(.system(size: 18, weight: .semibold))
                    Text("Watchlist")
                        .font(.headline)
                }
            }
            // Canonical glass secondary beside the WHITE primary CTA.
            .buttonStyle(VPButtonStyle(kind: .secondary))
            .accessibilityLabel(viewModel.isInWatchlist ? "Remove from Watchlist" : "Add to Watchlist")
            .accessibilityHint("Toggles this title in your watchlist.")

            Spacer(minLength: 0)
        }
        .padding(.top, 8)
    }

    private var watchStateRow: some View {
        let state = viewModel.currentWatchStatusState
        let actionTitle = state.isWatched ? "Mark Unwatched" : "Mark Watched"

        // Only the right-side capsule is the action; the left status (icon + label) is plain
        // content so the indicator isn't conflated with the tap target.
        return HStack(alignment: .center, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: watchStatusIcon(for: state))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(watchStatusColor(for: state))

                Text(state.label)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.92))
            }
            .accessibilityElement(children: .combine)

            Spacer()

            // Right side is the action half of the status-vs-action split: a dense
            // in-content control, so it targets the >=44 minimum (not the 60 primary floor).
            Button {
                Task { await viewModel.toggleCurrentWatchState() }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: state.isWatched ? "xmark" : "checkmark")
                        .font(.caption.weight(.semibold))
                    Text(actionTitle)
                        .font(.subheadline.weight(.semibold))
                }
                .foregroundStyle(.white.opacity(0.92))
                .padding(.horizontal, 14)
                .frame(minHeight: 44)
                .background(Capsule().fill(.white.opacity(0.12)))
            }
            .buttonStyle(.plain)
            .accessibilityLabel(actionTitle)
            .accessibilityHint("Updates the watched state for this title.")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Color.white.opacity(0.10), in: RoundedRectangle(cornerRadius: VPRadius.control, style: .continuous))
        .padding(.top, 4)
    }
    
    @ViewBuilder
    private var currentEpisodeRow: some View {
        if let episode = viewModel.selectedEpisode {
            HStack(alignment: .center, spacing: 10) {
                HStack(spacing: 8) {
                    Text(SeriesDetailPresentationPolicy.episodeContextText(
                        season: viewModel.selectedSeason,
                        episodeNumber: episode.episodeNumber
                    ))
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(.white.opacity(0.9))

                    if let episodeTitle = episode.title, !episodeTitle.isEmpty {
                        Text(episodeTitle)
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.7))
                    }

                    if let runtimeText = SeriesDetailPresentationPolicy.episodeRuntimeText(minutes: episode.runtime) {
                        Text(runtimeText)
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.6))
                    }
                }

                if mediaType == .series {
                    watchStatusBadge(for: selectedEpisodeWatchState)
                }
            }
            .padding(.top, 8)
        } else if mediaType == .series, !viewModel.episodes.isEmpty {
            Text("Select an episode to load streams and update watched state.")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.72))
                .padding(.top, 8)
        } else if mediaType == .series, viewModel.isLoading(.seasonEpisodes) {
            Text(SeriesSeasonLoadingPresentationPolicy.loadingTitle(for: viewModel.selectedSeason))
                .font(.caption)
                .foregroundStyle(.white.opacity(0.72))
                .padding(.top, 8)
            }
    }

    private var seriesTrackingRow: some View {
        HStack(alignment: .center, spacing: 12) {
            // currentEpisodeRow already prompts "Select an episode" right above, so show only the
            // press-and-hold tip here regardless of whether an episode is currently selected.
            Label("Press and hold an episode for watch options.", systemImage: "hand.point.up.left.fill")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.72))

            Spacer()

            Menu {
                if viewModel.selectedEpisode != nil {
                    Section("Episode") {
                        Button {
                            Task { await viewModel.toggleCurrentWatchState() }
                        } label: {
                            Label(
                                SeriesDetailPresentationPolicy.episodeWatchActionTitle(
                                    isWatched: selectedEpisodeWatchState.isWatched
                                ),
                                systemImage: selectedEpisodeWatchState.isWatched ? "xmark.circle" : "checkmark.circle"
                            )
                        }
                    }
                }

                Section("Series") {
                    Button {
                        Task { await viewModel.markSeriesWatched() }
                    } label: {
                        Label("Mark Series as Watched", systemImage: "checkmark.circle.fill")
                    }

                    Button(role: .destructive) {
                        Task { await viewModel.markSeriesUnwatched() }
                    } label: {
                        Label("Mark Series as Unwatched", systemImage: "xmark.circle")
                    }
                }

                Section("Season") {
                    Button {
                        Task { await viewModel.markSeasonWatched() }
                    } label: {
                        Label("Mark Season as Watched", systemImage: "checkmark.circle")
                    }

                    Button(role: .destructive) {
                        Task { await viewModel.markSeasonUnwatched() }
                    } label: {
                        Label("Mark Season as Unwatched", systemImage: "xmark.circle")
                    }
                }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "ellipsis.circle")
                        .font(.subheadline.weight(.semibold))
                    Text(seriesWatchProgressLabel)
                        .font(.caption.weight(.semibold))
                }
                .foregroundStyle(.white.opacity(0.92))
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color.white.opacity(0.10), in: Capsule())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Series watch actions")
            .accessibilityHint("Opens episode, season, and series watched options.")
        }
        .padding(.top, 4)
    }
    
    private var seasonsSection: some View {
        VStack(alignment: .leading, spacing: SeriesDetailPresentationPolicy.episodesSectionSpacing) {
            HStack(alignment: .center, spacing: 12) {
                Text("Seasons")
                    .font(.headline)
                    .foregroundStyle(.white)

                Spacer()

                if viewModel.isLoading(.seasonEpisodes) {
                    InlineLoadingStatusView(title: SeriesSeasonLoadingPresentationPolicy.loadingTitle(for: viewModel.selectedSeason))
                }
            }
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(viewModel.seasons, id: \.id) { season in
                        seasonTab(season: season)
                    }
                }
            }
            .allowsHitTesting(!viewModel.isLoading(.seasonEpisodes))
        }
        .padding(.top, 24)
    }
    
    private func seasonTab(season: Season) -> some View {
        let isSelected = viewModel.selectedSeason == season.seasonNumber
        
        return Button {
            Task {
                await viewModel.loadSeason(season.seasonNumber, configuration: metadataConfiguration)
            }
        } label: {
            // Season tabs are a selection control (>=44 dense target), so identity reads
            // through the brand accent — glass fill + thin accent ring + soft glow — not an
            // opaque white slab (which is reserved for THE primary action). Unselected text
            // sits at the textTertiary contrast floor.
            Text("\(season.seasonNumber)")
                .font(.subheadline)
                .fontWeight(isSelected ? .bold : .medium)
                .foregroundStyle(isSelected ? VPColor.textPrimary : VPColor.textTertiary)
                .frame(width: 44, height: 44)
                .background(.ultraThinMaterial, in: Circle())
                .overlay(
                    Circle()
                        .strokeBorder(VPColor.accent, lineWidth: isSelected ? 1.5 : 0)
                )
                .shadow(color: isSelected ? VPColor.accent.opacity(0.35) : .clear, radius: 8)
        }
        .buttonStyle(.plain)
        .disabled(viewModel.isLoading(.seasonEpisodes))
        .animation(.spring(response: 0.3), value: viewModel.selectedSeason)
    }
    
    private func episodesSection() -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .center, spacing: 12) {
                Text("Episodes")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .onAppear {
                        SeriesDetailQAScrollDebug.log("episodesSection mounted, episodes=\(viewModel.episodes.count)")
                    }

                Spacer()

                if viewModel.isLoading(.seasonEpisodes) {
                    InlineLoadingStatusView(title: "Refreshing episode list…")
                }
            }

            if viewModel.isLoading(.seasonEpisodes) && viewModel.episodes.isEmpty {
                seasonLoadingEpisodePlaceholders

                Text(SeriesSeasonLoadingPresentationPolicy.loadingMessage(for: viewModel.selectedSeason))
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.65))
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(spacing: SeriesDetailPresentationPolicy.episodesSectionSpacing) {
                        ForEach(viewModel.episodes) { episode in
                            episodeCard(episode: episode)
                        }
                    }
                }
                .allowsHitTesting(!viewModel.isLoading(.seasonEpisodes))
            }
        }
        .padding(.top, SeriesDetailPresentationPolicy.episodesSectionTopPadding)
    }
    
    private func episodeCard(episode: Episode) -> some View {
        let isSelected = viewModel.selectedEpisode?.id == episode.id
        let watchState = viewModel.watchHistory(for: episode)
        let isWatched = watchState?.isCompleted == true
        let progress = watchState?.progress ?? 0
        
        return Button {
            viewModel.selectEpisode(episode)
            Task {
                await viewModel.searchTorrents()
            }
        } label: {
            VStack(alignment: .leading, spacing: 8) {
            // Thumbnail container
                ZStack(alignment: .bottomLeading) {
                // Thumbnail
                    if let stillURL = episode.stillURL {
                        AsyncImage(url: stillURL) { phase in
                            switch phase {
                            case .success(let image):
                                image
                                    .resizable()
                                    .aspectRatio(16/9, contentMode: .fill)
                            default:
                                Rectangle()
                                    .fill(.gray.opacity(0.3))
                            }
                        }
                        .frame(
                            width: SeriesDetailPresentationPolicy.episodeCardWidth,
                            height: SeriesDetailPresentationPolicy.episodeCardHeight
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    } else {
                        Rectangle()
                            .fill(.gray.opacity(0.3))
                            .frame(
                                width: SeriesDetailPresentationPolicy.episodeCardWidth,
                                height: SeriesDetailPresentationPolicy.episodeCardHeight
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                
                    // Progress bar (uses scaleEffect instead of GeometryReader to avoid layout thrashing)
                    if progress > 0 && progress < 1 {
                        ZStack(alignment: .leading) {
                            Rectangle()
                                .fill(.tint.opacity(0.3))
                                .frame(height: 3)
                            Rectangle()
                                .fill(.tint)
                                .frame(maxWidth: .infinity)
                                .scaleEffect(x: progress, y: 1, anchor: .leading)
                                .frame(height: 3)
                        }
                        .frame(height: 3)
                    }
                
                    // Watched badge (checkmark)
                    if isWatched {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 22))
                            .foregroundStyle(.white)
                            .padding(8)
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                    }
                
                    // Episode number badge
                    Text("\(episode.episodeNumber)")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(.black.opacity(0.6), in: Capsule())
                        .padding(8)
                }
                .frame(
                    width: SeriesDetailPresentationPolicy.episodeCardWidth,
                    height: SeriesDetailPresentationPolicy.episodeCardHeight
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(isSelected ? Color.white : Color.clear, lineWidth: 2)
                )
            
                // Episode info
                VStack(alignment: .leading, spacing: 4) {
                    Text(SeriesDetailPresentationPolicy.episodeTitle(
                        episode.title,
                        episodeNumber: episode.episodeNumber
                    ))
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(.white)
                        .lineLimit(1)
                
                    if let runtime = episode.runtime, runtime > 0 {
                        Text("\(runtime)m")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.6))
                    }

                    HStack(spacing: 6) {
                        Image(systemName: isWatched ? "checkmark.circle.fill" : "circle")
                            .font(.caption2.weight(.semibold))
                        Text(SeriesDetailPresentationPolicy.episodeWatchLabel(isWatched: isWatched))
                            .font(.caption2.weight(.semibold))
                    }
                    .foregroundStyle(isWatched ? .green : .white.opacity(0.62))
                }
                .frame(width: SeriesDetailPresentationPolicy.episodeCardWidth, alignment: .leading)
            }
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button {
                Task { await viewModel.toggleEpisodeWatched(episode) }
            } label: {
                Label(
                    SeriesDetailPresentationPolicy.episodeWatchActionTitle(isWatched: isWatched),
                    systemImage: isWatched ? "xmark.circle" : "checkmark.circle"
                )
            }
        }
        .accessibilityLabel(SeriesDetailPresentationPolicy.episodeAccessibilityLabel(
            episodeNumber: episode.episodeNumber,
            title: episode.title
        ))
        .accessibilityValue(SeriesDetailPresentationPolicy.episodeAccessibilityValue(
            isWatched: isWatched,
            isSelected: isSelected
        ))
        .accessibilityHint("Opens this episode and refreshes available streams. Press and hold for watched options.")
    }
    
    private var seasonLoadingEpisodePlaceholders: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: SeriesDetailPresentationPolicy.episodesSectionSpacing) {
                ForEach(0..<3, id: \.self) { _ in
                    VStack(alignment: .leading, spacing: 8) {
                        SkeletonBlock(
                            width: SeriesDetailPresentationPolicy.episodeCardWidth,
                            height: SeriesDetailPresentationPolicy.episodeCardHeight,
                            cornerRadius: 8
                        )
                        SkeletonBlock(width: 180, height: 16, cornerRadius: 6)
                        SkeletonBlock(width: 72, height: 12, cornerRadius: 6)
                    }
                }
            }
        }
        .allowsHitTesting(false)
    }

    private func utilityGlyph(name: String) -> some View {
        Image(systemName: name)
            .font(.system(size: 18))
            .frame(width: 44, height: 44)
            .background(.ultraThinMaterial, in: Circle())
    }

    private func watchStatusIcon(for state: DetailWatchStatusState) -> String {
        SeriesDetailPresentationPolicy.watchStatusIcon(for: state)
    }

    private func watchStatusColor(for state: DetailWatchStatusState) -> Color {
        switch state {
        case .watched:
            return .green
        case .inProgress:
            return .yellow
        case .notWatched:
            return .white.opacity(0.65)
        case .selectionRequired:
            return .white.opacity(0.75)
        }
    }

    private var selectedEpisodeWatchState: DetailWatchStatusState {
        guard let selectedEpisode = viewModel.selectedEpisode else {
            return SeriesDetailPresentationPolicy.selectedEpisodeWatchState(
                hasSelectedEpisode: false,
                isSelectedEpisodeCompleted: false
            )
        }
        return SeriesDetailPresentationPolicy.selectedEpisodeWatchState(
            hasSelectedEpisode: true,
            isSelectedEpisodeCompleted: viewModel.isEpisodeWatched(selectedEpisode)
        )
    }

    private var seriesWatchProgressLabel: String {
        let tally = viewModel.seriesWatchTally
        return SeriesDetailPresentationPolicy.seriesWatchProgressLabel(
            watchedCount: tally.watched,
            seasonEpisodeCounts: [tally.total]
        )
    }

    private func watchStatusBadge(for state: DetailWatchStatusState) -> some View {
        HStack(spacing: 6) {
            Image(systemName: watchStatusIcon(for: state))
                .font(.caption.weight(.semibold))
            Text(state.label)
                .font(.caption.weight(.semibold))
        }
        .foregroundStyle(watchStatusColor(for: state))
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color.white.opacity(0.10), in: Capsule())
    }

    @ViewBuilder
    private func genrePills(_ genres: [String]) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(Array(genres.prefix(4)), id: \.self) { genre in
                    Text(genre)
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(.white.opacity(0.88))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .overlay(Capsule().stroke(.white.opacity(0.18), lineWidth: 1))
                }
            }
        }
    }
    
    private var torrentsSection: some View {
        DetailTorrentsSection(
            viewModel: viewModel,
            mediaType: mediaType,
            streamResultsAnchor: streamResultsAnchor,
            isPlayerOpening: $isPlayerOpening,
            playerOpeningError: $playerOpeningError,
            openingTorrentID: openingTorrentID,
            onPlayTorrent: onPlayTorrent
        )
        .padding(.top, 32)
    }
}
