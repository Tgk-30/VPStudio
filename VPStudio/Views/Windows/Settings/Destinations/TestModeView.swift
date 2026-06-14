import SwiftUI

// MARK: - Test Mode View

/// A visual QA launcher that displays every major VPStudio screen with
/// injected mock data, requiring no API keys or real credentials.
struct TestModeView: View {
    @Environment(AppState.self) private var appState
    @State private var selectedScreen: TestScreen?

    private let columns = [
        GridItem(.adaptive(minimum: 160, maximum: 200), spacing: 16)
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                headerSection
                screensGrid
            }
            .padding(24)
        }
        .navigationTitle("Test Mode")
        #if !os(macOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .sheet(item: $selectedScreen) { screen in
            TestScreenSheet(screen: screen)
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "flame.fill")
                    .foregroundStyle(.orange)
                Text("Visual QA")
                    .font(.headline)
                Spacer()
                Text("No API keys required")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(.orange.opacity(0.15), in: Capsule())
            }

            Text("Tap any screen to launch a live test version with realistic mock data. Use this to verify UI/UX without credentials or network access.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(16)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Screens Grid

    private var screensGrid: some View {
        LazyVGrid(columns: columns, spacing: 16) {
            ForEach(TestScreen.allCases) { screen in
                TestScreenTile(screen: screen) {
                    selectedScreen = screen
                }
            }
        }
    }
}

// MARK: - Screen Tile

private struct TestScreenTile: View {
    let screen: TestScreen
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(screen.color.opacity(0.15))
                        .frame(height: 80)

                    Image(systemName: screen.icon)
                        .font(.system(size: 28))
                        .foregroundStyle(screen.color)
                }

                VStack(spacing: 2) {
                    Text(screen.title)
                        .font(.caption)
                        .fontWeight(.semibold)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)

                    Text(screen.subtitle)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14))
            .overlay {
                RoundedRectangle(cornerRadius: 14)
                    .strokeBorder(.white.opacity(0.1), lineWidth: 0.5)
            }
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(screen.title), \(screen.subtitle)")
        .accessibilityHint("Opens the \(screen.title) preview screen.")
        #if os(visionOS)
        .hoverEffect(.lift)
        #endif
    }
}

// MARK: - Test Screen Definitions

enum TestScreen: String, CaseIterable, Identifiable, Sendable {
    case discover
    case search
    case searchResults
    case detailMovie
    case detailSeries
    case library
    case downloads
    case player
    case settings

    var id: String { rawValue }

    var title: String {
        switch self {
        case .discover: return "Discover"
        case .search: return "Search"
        case .searchResults: return "Search + Results"
        case .detailMovie: return "Movie Detail"
        case .detailSeries: return "Series Detail"
        case .library: return "Library"
        case .downloads: return "Downloads"
        case .player: return "Player"
        case .settings: return "Settings"
        }
    }

    var subtitle: String {
        switch self {
        case .discover: return "Hero + sections"
        case .search: return "Empty search"
        case .searchResults: return "Filters + results"
        case .detailMovie: return "Stream list"
        case .detailSeries: return "Episodes grid"
        case .library: return "Populated library"
        case .downloads: return "Active downloads"
        case .player: return "Controls + overlays"
        case .settings: return "All categories"
        }
    }

    var icon: String {
        switch self {
        case .discover: return "sparkles.tv"
        case .search: return "magnifyingglass"
        case .searchResults: return "line.3.horizontal.decrease.circle"
        case .detailMovie: return "film"
        case .detailSeries: return "film.stack"
        case .library: return "books.vertical"
        case .downloads: return "arrow.down.circle"
        case .player: return "play.circle"
        case .settings: return "gearshape"
        }
    }

    var color: Color {
        switch self {
        case .discover: return .purple
        case .search: return .blue
        case .searchResults: return .cyan
        case .detailMovie: return .orange
        case .detailSeries: return .pink
        case .library: return .green
        case .downloads: return .mint
        case .player: return .red
        case .settings: return .gray
        }
    }
}

enum TestScreenLaunchPolicy {
    static func screen(for rawValue: String?) -> TestScreen? {
        guard let normalizedValue = rawValue.map(normalized), !normalizedValue.isEmpty else {
            return nil
        }

        return TestScreen.allCases.first { screen in
            normalized(screen.rawValue) == normalizedValue
                || normalized(screen.title) == normalizedValue
        }
    }

    private static func normalized(_ value: String) -> String {
        value
            .lowercased()
            .filter { $0.isLetter || $0.isNumber }
    }
}

// MARK: - Test Screen Sheet

struct TestScreenSheet: View {
    let screen: TestScreen
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            screenContent
                .navigationTitle(screen.title)
                #if !os(macOS)
                .navigationBarTitleDisplayMode(.inline)
                #endif
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Close") { dismiss() }
                    }
                }
        }
    }

    @ViewBuilder
    private var screenContent: some View {
        switch screen {
        case .discover:
            SeededDiscoverPreview()
        case .search:
            SeededSearchPreview(showsResults: false)
        case .searchResults:
            SeededSearchPreview(showsResults: true)
        case .detailMovie:
            SeededDetailPreview(mediaType: .movie)
        case .detailSeries:
            SeededDetailPreview(mediaType: .series)
        case .library:
            SeededLibraryPreview()
        case .downloads:
            SeededDownloadsPreview()
        case .player:
            SeededPlayerPreview()
        case .settings:
            SeededSettingsPreview()
        }
    }
}

// MARK: - Discover (real surface, seeded)

/// Renders the **production** `DiscoverView` populated with real TMDB artwork so the actual
/// hero carousel, rows, and tiles can be visually QA'd without API keys. `AppState` is inherited
/// from the surrounding app environment.
private struct SeededDiscoverPreview: View {
    @State private var viewModel = DiscoverViewModel.seededPreview()

    var body: some View {
        DiscoverView(viewModel: viewModel)
    }
}

// MARK: - Detail (real surface, seeded)

/// Renders the **production** `DetailView` (→ `SeriesDetailLayout`) populated with seeded content so
/// the actual hero, metadata, genre chips, season picker, and stream sections can be visually QA'd
/// without API keys or network calls. `AppState` is inherited from the surrounding app environment;
/// `disablesAutomaticLoading` keeps the seeded view model from being overwritten by a TMDB refresh.
private struct SeededDetailPreview: View {
    @Environment(AppState.self) private var appState
    let mediaType: MediaType
    @State private var viewModel: DetailViewModel?

    var body: some View {
        Group {
            if let viewModel {
                DetailView(
                    preview: DetailPreviewSeed.preview(for: mediaType),
                    initialViewModel: viewModel,
                    disablesAutomaticLoading: true
                )
            } else {
                Color.clear
            }
        }
        .task {
            if viewModel == nil {
                viewModel = DetailPreviewSeed.seededViewModel(appState: appState, type: mediaType)
            }
        }
    }
}

// MARK: - Search (real surface, seeded)

/// Renders the **production** `SearchView` seeded for visual QA. `showsResults == false` shows the
/// idle Explore grid (genres + recent searches); `true` shows a populated results grid with an
/// active query and media-type filter. `disablesAutomaticTasks` keeps the seeded view model from
/// being cleared by the TMDB configuration pass that runs without an API key.
private struct SeededSearchPreview: View {
    let showsResults: Bool
    @State private var viewModel: SearchViewModel?

    var body: some View {
        Group {
            if let viewModel {
                SearchView(initialViewModel: viewModel, disablesAutomaticTasks: true)
            } else {
                Color.clear
            }
        }
        .task {
            if viewModel == nil {
                viewModel = SearchViewModel.seededPreview(showsResults: showsResults)
            }
        }
    }
}

// MARK: - Library (real surface, seeded)

/// Renders the **production** `LibraryView` seeded with a populated watchlist so the real grid,
/// folder chips, and `MediaCardView` tiles can be visually QA'd without credentials or database
/// access. `disablesAutomaticTasks` skips the reload that would otherwise replace seeded content.
private struct SeededLibraryPreview: View {
    var body: some View {
        LibraryView(
            initialSelectedList: LibraryPreviewSeed.listType,
            initialEntries: LibraryPreviewSeed.entries,
            initialFolders: LibraryPreviewSeed.folders,
            initialMediaItems: LibraryPreviewSeed.mediaItems,
            initialIsLoadingSelection: false,
            disablesAutomaticTasks: true
        )
    }
}

// MARK: - Downloads (real surface, seeded)

/// Renders the **production** `DownloadsView` with a seeded view model (two active downloads + one
/// completed) so the real group cards, progress bars, and status chips can be visually QA'd.
/// `disablesAutomaticTasks` skips the manager refresh that would clear the seeded groups.
private struct SeededDownloadsPreview: View {
    @Environment(AppState.self) private var appState
    @State private var viewModel: DownloadsViewModel?

    var body: some View {
        Group {
            if let viewModel {
                DownloadsView(viewModel: viewModel, disablesAutomaticTasks: true)
            } else {
                Color.clear
            }
        }
        .task {
            if viewModel == nil {
                let model = DownloadsViewModel(appState: appState)
                model.groups = DownloadsPreviewSeed.groups
                model.tasks = DownloadsPreviewSeed.tasks
                model.isLoading = false
                viewModel = model
            }
        }
    }
}

// MARK: - Settings (real surface)

/// Renders the **production** `SettingsView` root. Its category list comes from the static
/// `SettingsNavigationCatalog`, so no seeding is needed; `disablesAutomaticTasks` skips the
/// per-destination status refresh that would otherwise hit the database / network.
private struct SeededSettingsPreview: View {
    var body: some View {
        SettingsView(disablesAutomaticTasks: true)
    }
}

// MARK: - Player (real surface, seeded)

/// Renders the **production** `PlayerView` chrome seeded for visual QA. `disablesAutomaticTasks`
/// skips `preparePlayback`, so no `AVPlayer` is created and no stream/network is touched — the
/// playback surface stays a harmless black fill while the real transport dock, top bar, info pills,
/// scrubber, time labels, and chapter markers render from a pre-seeded `VPPlayerEngine` injected
/// through the environment (the same way the live "player" window provides its `sharedEngine`).
/// `initialPlaybackState: .playing` suppresses the startup/"Playback Failed" overlay. The seed is
/// built in `.task` because `VPPlayerEngine` is `@MainActor` and can't initialize a `@State` default
/// from the view's nonisolated `init`. See `PlayerPreviewSeed`.
private struct SeededPlayerPreview: View {
    @State private var engine: VPPlayerEngine?
    #if os(visionOS)
    @State private var cinemaSettings = CinemaSettings()
    #endif

    var body: some View {
        Group {
            if let engine {
                PlayerView(
                    stream: PlayerPreviewSeed.stream,
                    mediaTitle: PlayerPreviewSeed.mediaTitle,
                    initialPlaybackState: .playing,
                    initialActiveEngine: PlayerPreviewSeed.activeEngine,
                    disablesAutomaticTasks: true
                )
                .environment(engine)
                #if os(visionOS)
                .environment(cinemaSettings)
                #endif
            } else {
                Color.black
            }
        }
        .task {
            if engine == nil {
                engine = PlayerPreviewSeed.makeSeededEngine()
            }
        }
    }
}
