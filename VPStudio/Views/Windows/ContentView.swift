import SwiftUI

enum NavigationChromePolicy {
    static func usesSidebar(for layout: NavigationLayout) -> Bool {
        layout == .leftSidebar
    }

    static func usesBottomTabBar(for layout: NavigationLayout) -> Bool {
        layout == .bottomTabBar
    }
}

enum BottomTabOrnamentPolicy {
    static let visionYOffset: CGFloat = 8
    static let visionRegularChromeScale: CGFloat = 1.14
    static let visionCompactChromeScale: CGFloat = 1.08
}

enum BottomTabAction: Equatable {
    case select(SidebarTab)
    case openEnvironmentPicker
}

enum BottomTabRoutingPolicy {
    static func action(for tab: SidebarTab, opensEnvironmentPicker: Bool) -> BottomTabAction {
        if tab == .environments, opensEnvironmentPicker {
            return .openEnvironmentPicker
        }
        return .select(tab)
    }
}

enum RootTabSelectionPolicy {
    enum NavigationAction: Equatable {
        case clearPath
        case resetStack
    }

    static func navigationAction(currentTab: SidebarTab, selectedTab: SidebarTab) -> NavigationAction {
        currentTab == selectedTab ? .resetStack : .clearPath
    }

    static func shouldResetNavigationStack(currentTab: SidebarTab, selectedTab: SidebarTab) -> Bool {
        navigationAction(currentTab: currentTab, selectedTab: selectedTab) == .resetStack
    }

    static func shouldClearNavigationPath(currentTab: SidebarTab, selectedTab: SidebarTab) -> Bool {
        navigationAction(currentTab: currentTab, selectedTab: selectedTab) == .clearPath
    }
}

enum RootNavigationBadgePolicy {
    static func activeDownloadCount(from tasks: [DownloadTask]) -> Int {
        tasks.filter { !$0.status.isTerminal }.count
    }

    static func settingsWarningCount(from snapshot: SettingsStatusSnapshot) -> Int {
        SettingsNavigationCatalog.orderedDestinations.filter {
            SettingsStatusFormatter.status(for: $0, snapshot: snapshot).kind == .warning
        }.count
    }
}

enum QuickStartPromptPolicy {
    static let skipSetupDestination: SidebarTab = .library
    static let skipSetupTitle = "Browse Library"
    static let bodyCopy = "Skip setup for now and browse Library, or run setup to unlock Discover, Search, and streaming features."

    static func restoredTab(from rawValue: String) -> SidebarTab? {
        SidebarTab(rawValue: rawValue) ?? (rawValue == "Search" ? .search : nil)
    }

    static func shouldShowPrompt(
        setupRecommendationNeeded: Bool,
        promptDismissed: Bool,
        selectedTab: SidebarTab,
        promptSuppressed: Bool = false,
        visualSetupSurfaceAvailable: Bool = false
    ) -> Bool {
        setupRecommendationNeeded
            && !promptDismissed
            && !promptSuppressed
            && !visualSetupSurfaceAvailable
            && selectedTab == .discover
    }
}

enum RootLaunchOverlayPolicy {
    static func shouldShowLaunchOverlay(
        isBootstrapping: Bool,
        qaTestScreenRawValue: String?
    ) -> Bool {
        isBootstrapping && TestScreenLaunchPolicy.screen(for: qaTestScreenRawValue) == nil
    }
}

#if os(macOS)
private struct QATestScreenPresentationModifier: ViewModifier {
    @Binding var screen: TestScreen?
    let appState: AppState

    func body(content: Content) -> some View {
        content
            .sheet(item: $screen) { screen in
                TestScreenSheet(screen: screen)
                    .environment(appState)
                    .frame(minWidth: 900, minHeight: 600)
        }
    }
}
#elseif os(visionOS)
private struct QATestScreenPresentationModifier: ViewModifier {
    @Binding var screen: TestScreen?
    let appState: AppState

    func body(content: Content) -> some View {
        content
            .fullScreenCover(item: $screen) { screen in
                TestScreenSheet(screen: screen)
                    .environment(appState)
        }
    }
}
#else
#error("QATestScreenPresentationModifier supports macOS and visionOS only.")
#endif

#if os(macOS) || os(visionOS)
private struct MainWindowPlayerTerminationModifier: ViewModifier {
    let scenePhase: ScenePhase
    let terminate: () -> Void

    func body(content: Content) -> some View {
        content
            .onAppear(perform: terminate)
            .onChange(of: scenePhase) { _, phase in
                guard phase == .active else { return }
                terminate()
            }
    }
}
#endif

// MARK: - ContentView

struct ContentView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage("onboarding.soft_setup_dismissed") private var softSetupPromptDismissed = false

    #if os(macOS) || os(visionOS)
    @Environment(\.dismissWindow) private var dismissWindow
    #endif

    @State private var discoverViewModel = DiscoverViewModel()
    @State private var isShowingQuickStartPrompt = false
    @State private var activeDownloadCount = 0
    @State private var settingsWarningCount = 0
    @State private var rootNavigationPath = NavigationPath()
    @State private var qaPresentedTestScreen: TestScreen?
    @State private var downloadBadgeRefreshTask: Task<Void, Never>?
    @State private var settingsBadgeRefreshTask: Task<Void, Never>?
    @State private var rootBadgeRefreshTask: Task<Void, Never>?
    #if os(macOS) || os(visionOS)
    /// Last player session we observed as active. Retained so the main-window
    /// reappearance fallback can issue a precise value-keyed `dismissWindow` even
    /// if `appState.activePlayerSession` was already niled by the time the main
    /// window comes back (e.g. `closePlayer` cleared the session before the
    /// dismiss landed). Without this, the player window could survive as a dead
    /// window on KSPlayer-path streams.
    @State private var pendingPlayerWindowDismiss: PlayerSessionRequest?
    #endif
    private let disablesAutomaticTasks: Bool

    #if os(visionOS)
    @Environment(\.openImmersiveSpace) private var openImmersiveSpace
    @Environment(\.dismissImmersiveSpace) private var dismissImmersiveSpace
    @State private var isShowingEnvironmentPicker = false
    @State private var environmentPickerError: String?
    #endif

    @MainActor
    init(
        initialDiscoverViewModel: DiscoverViewModel? = nil,
        initialIsShowingQuickStartPrompt: Bool = false,
        initialActiveDownloadCount: Int = 0,
        initialSettingsWarningCount: Int = 0,
        disablesAutomaticTasks: Bool = false
    ) {
        _discoverViewModel = State(initialValue: initialDiscoverViewModel
            ?? (QARuntimeOptions.seedDiscoverPreview ? .seededPreview() : DiscoverViewModel()))
        _isShowingQuickStartPrompt = State(initialValue: initialIsShowingQuickStartPrompt)
        _activeDownloadCount = State(initialValue: initialActiveDownloadCount)
        _settingsWarningCount = State(initialValue: initialSettingsWarningCount)
        self.disablesAutomaticTasks = disablesAutomaticTasks
    }

    var body: some View {
        @Bindable var state = appState

        ZStack {
            NavigationStack(path: $rootNavigationPath) {
                contentView(for: state.selectedTab)
            }
            .id(state.navigationResetID)
            .transition(
                .opacity.combined(
                    with: .scale(TabTransitionPolicy.scaleEffect)
                )
            )
            .animation(
                .spring(
                    response: TabTransitionPolicy.springResponse,
                    dampingFraction: TabTransitionPolicy.springDamping
                ),
                value: state.selectedTab
            )

            // Launch screen overlay — fades out once bootstrap completes
            if RootLaunchOverlayPolicy.shouldShowLaunchOverlay(
                isBootstrapping: appState.isBootstrapping,
                qaTestScreenRawValue: QARuntimeOptions.testScreenRawValue
            ) {
                LaunchScreen()
                    .transition(.opacity)
                    .zIndex(100)
            }
        }
        .animation(.easeOut(duration: 0.6), value: appState.isBootstrapping)
        .safeAreaInset(edge: .top) {
            if !appState.networkMonitor.isConnected {
                HStack(spacing: 8) {
                    Image(systemName: "wifi.slash")
                        .font(.caption.weight(.semibold))
                    Text("You're offline — downloaded content is still available")
                        .font(.caption.weight(.medium))
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .frame(maxWidth: .infinity)
                .background(.orange.gradient)
            }
        }
        .background(Color.black.opacity(0.6))
        .sheet(isPresented: $state.isShowingSetup) {
            SetupWizardView()
        }
        // QA visual screens render full-window where the API is available; macOS
        // package builds use a sheet because fullScreenCover(item:) is unavailable.
        .modifier(QATestScreenPresentationModifier(
            screen: $qaPresentedTestScreen,
            appState: appState
        ))
        .overlay(alignment: .top) {
            if isShowingQuickStartPrompt, state.selectedTab == .discover {
                QuickStartPromptView(
                    onExploreNow: {
                        softSetupPromptDismissed = true
                        isShowingQuickStartPrompt = false
                        selectRootTab(QuickStartPromptPolicy.skipSetupDestination, state: state)
                    },
                    onRunSetup: {
                        softSetupPromptDismissed = true
                        isShowingQuickStartPrompt = false
                        appState.isShowingSetup = true
                    },
                    onDismiss: {
                        softSetupPromptDismissed = true
                        isShowingQuickStartPrompt = false
                    }
                )
                .padding(.top, 16)
                .padding(.horizontal, 20)
                .transition(.move(edge: .top).combined(with: .opacity))
                .zIndex(90)
            }
        }
        .frame(minWidth: 900, minHeight: 600)
        .animation(.spring(response: 0.45, dampingFraction: 0.85), value: isShowingQuickStartPrompt)
        #if os(macOS) || os(visionOS)
        .onChange(of: appState.activePlayerSession) { _, session in
            // Remember the active session while it exists so the reappearance
            // fallback can still target it for dismissal after it's cleared.
            if let session {
                pendingPlayerWindowDismiss = session
            }
        }
        .modifier(MainWindowPlayerTerminationModifier(
            scenePhase: scenePhase,
            terminate: { terminatePlayerIfMainWindowOpened() }
        ))
        #endif
        .task {
            guard !disablesAutomaticTasks else { return }
            presentQATestScreenIfRequested()
            discoverViewModel.configure(database: appState.database)
            await appState.bootstrap()
            // Restore persisted tab selection after bootstrap (settings DB is now ready)
            if let savedTab = try? await appState.settingsManager.getString(key: SettingsKeys.lastSelectedTab) {
                // Backward compat: accept legacy "Search" raw value after rename to "Explore"
                if let tab = QuickStartPromptPolicy.restoredTab(from: savedTab) {
                    appState.selectedTab = tab
                }
            }
            // Restore persisted navigation layout
            if let savedLayout = try? await appState.settingsManager.getString(key: SettingsKeys.navigationLayout),
               let layout = NavigationLayout(rawValue: savedLayout) {
                appState.navigationLayout = layout
            }
            if let qaSelectedTab = QARuntimeOptions.selectedTab {
                appState.selectedTab = qaSelectedTab
            }
            if let qaNavigationLayout = QARuntimeOptions.navigationLayout {
                appState.navigationLayout = qaNavigationLayout
            }
            await refreshRootBadgeCounts()
            await appState.runQATraktRefreshIfRequested()
            RuntimeMemoryDiagnostics.capture(
                event: .appBootstrapCompleted,
                enabled: appState.runtimeDiagnosticsEnabled
            )
            presentQATestScreenIfRequested()
            if QuickStartPromptPolicy.shouldShowPrompt(
                setupRecommendationNeeded: appState.setupRecommendationNeeded,
                promptDismissed: softSetupPromptDismissed,
                selectedTab: state.selectedTab,
                promptSuppressed: QARuntimeOptions.suppressQuickStartPrompt,
                visualSetupSurfaceAvailable: true
            ) {
                isShowingQuickStartPrompt = true
            }
        }
        .task(id: state.selectedTab) {
            guard !disablesAutomaticTasks else { return }
            guard !appState.isBootstrapping else { return }
            if appState.setupRecommendationNeeded, !softSetupPromptDismissed {
                isShowingQuickStartPrompt = QuickStartPromptPolicy.shouldShowPrompt(
                    setupRecommendationNeeded: appState.setupRecommendationNeeded,
                    promptDismissed: softSetupPromptDismissed,
                    selectedTab: state.selectedTab,
                    promptSuppressed: QARuntimeOptions.suppressQuickStartPrompt,
                    visualSetupSurfaceAvailable: true
                )
            }
            await refreshRootBadgeCounts()
        }
        .onChange(of: state.isShowingSetup) { _, isShowingSetup in
            if isShowingSetup {
                softSetupPromptDismissed = true
                isShowingQuickStartPrompt = false
            }
        }
        .onChange(of: state.selectedTab) { previous, next in
            if RootTabSelectionPolicy.shouldClearNavigationPath(currentTab: previous, selectedTab: next) {
                rootNavigationPath = NavigationPath()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .downloadsDidChange)) { _ in
            guard !disablesAutomaticTasks else { return }
            scheduleDownloadBadgeRefresh()
        }
        .onReceive(NotificationCenter.default.publisher(for: .metadataApiKeyDidChange)) { _ in
            guard !disablesAutomaticTasks else { return }
            scheduleSettingsBadgeRefresh()
        }
        .onReceive(NotificationCenter.default.publisher(for: .indexersDidChange)) { _ in
            guard !disablesAutomaticTasks else { return }
            scheduleSettingsBadgeRefresh()
        }
        .onReceive(NotificationCenter.default.publisher(for: .environmentsDidChange)) { _ in
            guard !disablesAutomaticTasks else { return }
            scheduleSettingsBadgeRefresh()
        }
        .onReceive(NotificationCenter.default.publisher(for: .localModelsDidChange)) { _ in
            guard !disablesAutomaticTasks else { return }
            scheduleSettingsBadgeRefresh()
        }
        .onReceive(NotificationCenter.default.publisher(for: .openSubtitlesDidChange)) { _ in
            guard !disablesAutomaticTasks else { return }
            scheduleSettingsBadgeRefresh()
        }
        .onReceive(NotificationCenter.default.publisher(for: .appDidResetAllData)) { _ in
            guard !disablesAutomaticTasks else { return }
            scheduleRootBadgeRefresh()
        }
        .onDisappear {
            cancelBadgeRefreshTasks()
        }
        #if os(visionOS)
        .ornament(attachmentAnchor: .scene(.bottom), contentAlignment: .top) {
            if appState.navigationLayout == .bottomTabBar {
                VPBottomTabBar(
                    selectedTab: $state.selectedTab,
                    opensEnvironmentPicker: true,
                    onOpenEnvironmentPicker: { isShowingEnvironmentPicker = true },
                    onTabSelection: { tab in handleTabSelection(tab, state: state) },
                    activeDownloadCount: activeDownloadCount,
                    settingsWarningCount: settingsWarningCount
                )
                .environment(appState)
                .offset(y: BottomTabOrnamentPolicy.visionYOffset)
            }
        }
        .ornament(attachmentAnchor: .scene(.leading), contentAlignment: .trailing) {
            if appState.navigationLayout == .leftSidebar {
                VPSidebarView(
                    selectedTab: $state.selectedTab,
                    opensEnvironmentPicker: true,
                    onOpenEnvironmentPicker: { isShowingEnvironmentPicker = true },
                    onTabSelection: { tab in handleTabSelection(tab, state: state) },
                    activeDownloadCount: activeDownloadCount,
                    settingsWarningCount: settingsWarningCount
                )
                .environment(appState)
            }
        }
        .sheet(isPresented: $isShowingEnvironmentPicker) {
            EnvironmentPickerSheet(
                onSelect: { asset in
                    Task { await openEnvironment(asset) }
                },
                onDismiss: {
                    Task {
                        guard await dismissEnvironmentIfNeeded(reason: .userInitiated) else {
                            environmentPickerError = PlayerImmersiveTransitionPolicy.transitionBusyMessage
                            return
                        }
                    }
                },
                onSelectCinema: {
                    Task { await openCinemaEnvironment() }
                },
                onClear: {
                    Task { await clearEnvironmentSelection() }
                }
            )
            .environment(appState)
        }
        .alert(
            "Environment Error",
            isPresented: Binding(
                get: { environmentPickerError != nil },
                set: { isPresented in
                    if !isPresented { environmentPickerError = nil }
                }
            )
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(environmentPickerError ?? "Unknown error")
        }
        #else
        .safeAreaInset(edge: .bottom) {
            if appState.navigationLayout == .bottomTabBar {
                VPBottomTabBar(
                    selectedTab: $state.selectedTab,
                    opensEnvironmentPicker: false,
                    onOpenEnvironmentPicker: {},
                    onTabSelection: { tab in handleTabSelection(tab, state: state) },
                    activeDownloadCount: activeDownloadCount,
                    settingsWarningCount: settingsWarningCount
                )
                .padding(.horizontal, 12)
                .padding(.top, 8)
                .padding(.bottom, 10)
            }
        }
        .safeAreaInset(edge: .leading) {
            if appState.navigationLayout == .leftSidebar {
                VPSidebarView(
                    selectedTab: $state.selectedTab,
                    opensEnvironmentPicker: false,
                    onOpenEnvironmentPicker: {},
                    onTabSelection: { tab in handleTabSelection(tab, state: state) },
                    activeDownloadCount: activeDownloadCount,
                    settingsWarningCount: settingsWarningCount
                )
                .padding(.vertical, 12)
                .padding(.leading, 10)
            }
        }
        #endif
    }

    #if os(macOS) || os(visionOS)
    private func terminatePlayerIfMainWindowOpened() {
        guard appState.activePlayerSession != nil || appState.isMainWindowSuppressedForPlayer else { return }

        // Prefer the live session, then fall back to the retained pending-dismiss
        // target so the value-keyed dismiss can still match the window even if
        // `activePlayerSession` was niled before the main window reappeared
        // (which would otherwise leave a dead player window open on the
        // KSPlayer-path streams).
        if let activeSession = appState.activePlayerSession ?? pendingPlayerWindowDismiss {
            dismissWindow(id: "player", value: activeSession)
        }
        dismissWindow(id: "player")
        appState.terminateActivePlayerSession()
        pendingPlayerWindowDismiss = nil
    }
    #endif

    private func handleTabSelection(_ tab: SidebarTab, state: AppState) {
        selectRootTab(tab, state: state)
    }

    private func selectRootTab(_ tab: SidebarTab, state: AppState) {
        let navigationAction = RootTabSelectionPolicy.navigationAction(
            currentTab: state.selectedTab,
            selectedTab: tab
        )

        if navigationAction == .clearPath {
            rootNavigationPath = NavigationPath()
        }

        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            state.selectedTab = tab

            if navigationAction == .resetStack {
                rootNavigationPath = NavigationPath()
                // Same-tab reselect = pop to root. Clear the active tab's item-driven detail
                // selection so an open DetailView dismisses. (This previously regenerated
                // navigationResetID, which tore down and rebuilt the entire tab subtree — a
                // blank/reload flash — and, now that detail state lives in AppState, would just
                // re-push the same detail instead of popping it. navigationResetID is now
                // reserved for hard resets via AppState.resetAllData.)
                clearActiveTabDetailSelection(tab, state: state)
            }
        }

        Task { try? await appState.settingsManager.setValue(tab.rawValue, forKey: SettingsKeys.lastSelectedTab) }
        RuntimeMemoryDiagnostics.capture(
            event: .tabSelectionChanged,
            enabled: appState.runtimeDiagnosticsEnabled,
            context: tab.rawValue
        )
    }

    /// Clears the given tab's hoisted detail selection so a same-tab reselect pops to root.
    private func clearActiveTabDetailSelection(_ tab: SidebarTab, state: AppState) {
        switch tab {
        case .library: state.libraryDetailSelection = nil
        case .discover: state.discoverDetailRoute = nil
        case .search:
            state.searchDetailSelection = nil
            state.searchDetailInitialAction = .none
        case .downloads, .environments, .settings: break
        }
    }

    private func presentQATestScreenIfRequested() {
        guard let screen = TestScreenLaunchPolicy.screen(for: QARuntimeOptions.testScreenRawValue) else { return }

        softSetupPromptDismissed = true
        isShowingQuickStartPrompt = false
        appState.isShowingSetup = false
        appState.isBootstrapping = false
        qaPresentedTestScreen = screen
    }

    private func refreshRootBadgeCounts() async {
        await refreshDownloadBadgeCount()
        await refreshSettingsBadgeCount()
    }

    private func refreshDownloadBadgeCount() async {
        guard let tasks = try? await appState.downloadManager.listDownloads() else { return }
        guard !Task.isCancelled else { return }
        activeDownloadCount = RootNavigationBadgePolicy.activeDownloadCount(from: tasks)
    }

    private func refreshSettingsBadgeCount() async {
        let snapshot = await captureSettingsStatusSnapshot()
        guard !Task.isCancelled else { return }
        settingsWarningCount = RootNavigationBadgePolicy.settingsWarningCount(from: snapshot)
    }

    private func scheduleDownloadBadgeRefresh() {
        downloadBadgeRefreshTask?.cancel()
        downloadBadgeRefreshTask = Task { await refreshDownloadBadgeCount() }
    }

    private func scheduleSettingsBadgeRefresh() {
        settingsBadgeRefreshTask?.cancel()
        settingsBadgeRefreshTask = Task { await refreshSettingsBadgeCount() }
    }

    private func scheduleRootBadgeRefresh() {
        downloadBadgeRefreshTask?.cancel()
        settingsBadgeRefreshTask?.cancel()
        rootBadgeRefreshTask?.cancel()
        rootBadgeRefreshTask = Task { await refreshRootBadgeCounts() }
    }

    private func cancelBadgeRefreshTasks() {
        downloadBadgeRefreshTask?.cancel()
        downloadBadgeRefreshTask = nil
        settingsBadgeRefreshTask?.cancel()
        settingsBadgeRefreshTask = nil
        rootBadgeRefreshTask?.cancel()
        rootBadgeRefreshTask = nil
    }

    @ViewBuilder
    private func contentView(for tab: SidebarTab) -> some View {
        switch tab {
        case .discover:
            DiscoverView(
                viewModel: discoverViewModel,
                suppressSetupSurface: isShowingQuickStartPrompt
            )
        case .search:
            SearchView()
        case .library:
            LibraryView()
        case .downloads:
            DownloadsView()
        case .environments:
            EnvironmentsTabView()
        case .settings:
            SettingsView()
        }
    }

    private func captureSettingsStatusSnapshot() async -> SettingsStatusSnapshot {
        var snapshot = SettingsStatusSnapshot()

        if let configs = try? await appState.database.fetchAllDebridConfigs() {
            snapshot.activeDebridCount = configs.filter(\.isActive).count
        }

        if let configs = try? await appState.database.fetchAllIndexerConfigs() {
            snapshot.activeIndexerCount = configs.filter(\.isActive).count
        }

        let metadataApiKey = (try? await appState.settingsManager.getMetadataApiKey()) ?? ""
        snapshot.hasMetadataKey = !metadataApiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        snapshot.hasOpenSubtitlesKey = await hasNonEmptyString(for: SettingsKeys.openSubtitlesApiKey)

        if let assets = try? await appState.environmentCatalogManager.fetchAssets() {
            snapshot.environmentAssetCount = assets.count
        }

        let providerRaw = (try? await appState.settingsManager.getString(key: SettingsKeys.defaultAIProvider))
            ?? AIProviderKind.anthropic.rawValue
        snapshot.aiProvider = AIProviderKind(rawValue: providerRaw) ?? .anthropic

        snapshot.hasOpenAIKey = await hasNonEmptyString(for: SettingsKeys.openAIApiKey)
        snapshot.hasAnthropicKey = await hasNonEmptyString(for: SettingsKeys.anthropicApiKey)
        snapshot.hasGeminiKey = await hasNonEmptyString(for: SettingsKeys.geminiApiKey)
        snapshot.hasOllamaEndpoint = await hasNonEmptyString(
            for: SettingsKeys.ollamaEndpoint,
            fallback: "http://localhost:11434"
        )
        snapshot.hasOpenRouterKey = await hasNonEmptyString(for: SettingsKeys.openRouterApiKey)
        snapshot.hasMistralKey = await hasNonEmptyString(for: SettingsKeys.mistralApiKey)
        snapshot.hasMiniMaxKey = await hasNonEmptyString(for: SettingsKeys.minimaxApiKey)

        let localConfiguration = await appState.localAIProviderConfiguration()
        snapshot.isLocalAIEnabled = localConfiguration.isEnabled
        snapshot.hasUsableLocalModel = localConfiguration.isUsable

        let userTraktClient = try? await appState.settingsManager.getString(key: SettingsKeys.traktClientId)
        let userTraktSecret = try? await appState.settingsManager.getString(key: SettingsKeys.traktClientSecret)
        snapshot.hasTraktCredentials = TraktDefaults.resolvedCredentials(
            userClientId: userTraktClient,
            userClientSecret: userTraktSecret
        ) != nil

        let hasSimklClient = await hasNonEmptyString(for: SettingsKeys.simklClientId)
        let hasSimklToken = await hasNonEmptyString(for: SettingsKeys.simklAccessToken)
        snapshot.hasSimklCredentials = hasSimklClient && hasSimklToken

        return snapshot
    }

    private func hasNonEmptyString(for key: String, fallback: String? = nil) async -> Bool {
        let value = (try? await appState.settingsManager.getString(key: key)) ?? fallback
        return !(value?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true)
    }

    // MARK: - visionOS Environment Logic

    #if os(visionOS)
    private func openCinemaEnvironment() async {
        if appState.activeEnvironment == .cinemaEnvironment, appState.isImmersiveSpaceOpen {
            guard await dismissEnvironmentIfNeeded(reason: .userInitiated) else {
                environmentPickerError = PlayerImmersiveTransitionPolicy.transitionBusyMessage
                return
            }
            return
        }

        guard await dismissEnvironmentIfNeeded(reason: .switchingEnvironment) else {
            environmentPickerError = PlayerImmersiveTransitionPolicy.transitionBusyMessage
            return
        }
        guard appState.beginImmersiveTransition() else {
            environmentPickerError = PlayerImmersiveTransitionPolicy.transitionBusyMessage
            return
        }
        let result = await openImmersiveSpace(id: EnvironmentType.cinemaEnvironment.immersiveSpaceId)
        switch result {
        case .opened:
            appState.spatialAudioManager.enterImmersiveMode()
        case .error, .userCancelled:
            appState.cancelImmersiveTransition()
        @unknown default:
            appState.cancelImmersiveTransition()
        }
    }

    private func openEnvironment(_ asset: EnvironmentAsset) async {
        if asset.id == appState.selectedEnvironmentAsset?.id, appState.isImmersiveSpaceOpen {
            guard await dismissEnvironmentIfNeeded(reason: .userInitiated) else {
                environmentPickerError = PlayerImmersiveTransitionPolicy.transitionBusyMessage
                return
            }
            return
        }

        guard await ensureImportedEnvironmentAssetExists(asset) else {
            environmentPickerError = PlayerImmersiveTransitionPolicy.missingAssetMessage(assetName: asset.name)
            return
        }
        guard await dismissEnvironmentIfNeeded(reason: .switchingEnvironment) else {
            environmentPickerError = PlayerImmersiveTransitionPolicy.transitionBusyMessage
            return
        }
        guard await appState.activateEnvironmentAsset(asset) else {
            environmentPickerError = PlayerImmersiveTransitionPolicy.missingAssetMessage(assetName: asset.name)
            return
        }

        guard appState.beginImmersiveTransition() else {
            await appState.clearEnvironmentSelectionIfCurrent(assetID: asset.id)
            environmentPickerError = PlayerImmersiveTransitionPolicy.transitionBusyMessage
            return
        }
        let spaceID = await appState.environmentCatalogManager.immersiveSpaceID(for: asset)
        let result = await openImmersiveSpace(id: spaceID)
        switch result {
        case .opened:
            break
        case .error, .userCancelled:
            appState.cancelImmersiveTransition()
            await appState.clearEnvironmentSelectionIfCurrent(assetID: asset.id)
            environmentPickerError = PlayerImmersiveTransitionPolicy.openFailedMessage(assetName: asset.name)
        @unknown default:
            appState.cancelImmersiveTransition()
            await appState.clearEnvironmentSelectionIfCurrent(assetID: asset.id)
            environmentPickerError = PlayerImmersiveTransitionPolicy.openFailedMessage(assetName: asset.name)
        }
    }

    private func ensureImportedEnvironmentAssetExists(_ asset: EnvironmentAsset) async -> Bool {
        guard asset.sourceType == .imported else { return true }
        if await appState.environmentCatalogManager.resolvedAssetURL(for: asset) != nil {
            return true
        }

        try? await appState.environmentCatalogManager.deleteAsset(id: asset.id)
        await appState.clearEnvironmentSelectionIfCurrent(assetID: asset.id)
        return false
    }

    @discardableResult
    private func dismissEnvironmentIfNeeded(reason: ImmersiveDismissReason) async -> Bool {
        guard appState.isImmersiveSpaceOpen else { return true }
        guard appState.beginImmersiveTransition() else { return false }
        appState.stageImmersiveDismiss(reason: reason)
        await dismissImmersiveSpace()
        appState.completeImmersiveDismissIfStillPending()
        return true
    }

    private func clearEnvironmentSelection() async {
        guard await dismissEnvironmentIfNeeded(reason: .userInitiated) else {
            environmentPickerError = PlayerImmersiveTransitionPolicy.transitionBusyMessage
            return
        }
        await appState.clearEnvironmentSelection()
    }
    #endif
}

private struct QuickStartPromptView: View {
    let onExploreNow: () -> Void
    let onRunSetup: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "sparkles")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Color.vpRed)
                VStack(alignment: .leading, spacing: 3) {
                    Text("Quick Start")
                        .font(.headline)
                    Text(QuickStartPromptPolicy.bodyCopy)
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.76))
                }
                Spacer(minLength: 0)
                Button(action: onDismiss) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundStyle(.white.opacity(0.72))
                        .accessibilityLabel("Dismiss quick start")
                }
                .buttonStyle(.plain)
            }

            HStack(spacing: 10) {
                Button(action: onExploreNow) {
                    Label(QuickStartPromptPolicy.skipSetupTitle, systemImage: "books.vertical.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)

                Button(action: onRunSetup) {
                    Label("Run Setup", systemImage: "slider.horizontal.3")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            }
        }
        .foregroundStyle(.white)
        .padding(16)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .background {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.12),
                            Color.vpRed.opacity(0.08),
                            Color.black.opacity(0.14),
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        }
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.30),
                            Color.vpRed.opacity(0.18),
                            Color.white.opacity(0.08),
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        }
        .glassShadow()
        .frame(maxWidth: 760)
    }

}

// MARK: - Bottom Tab Bar

struct VPBottomTabBar: View {
    @Binding var selectedTab: SidebarTab
    let opensEnvironmentPicker: Bool
    let onOpenEnvironmentPicker: () -> Void
    let onTabSelection: (SidebarTab) -> Void

    /// Counts driving badge visibility — wired by parent or defaults to 0.
    var activeDownloadCount: Int = 0
    var settingsWarningCount: Int = 0
    @State private var hoveredTab: SidebarTab?

    #if os(visionOS)
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.verticalSizeClass) private var verticalSizeClass

    /// Vision Pro compact layouts need a slightly larger hit target than legacy baseline,
    /// while regular layouts keep the current 25% upscale from production.
    private var chromeScale: CGFloat {
        if QARuntimeOptions.forceCompactNavScale {
            return BottomTabOrnamentPolicy.visionCompactChromeScale
        }

        if horizontalSizeClass == .compact || verticalSizeClass == .compact {
            return BottomTabOrnamentPolicy.visionCompactChromeScale
        }
        return BottomTabOrnamentPolicy.visionRegularChromeScale
    }
    #else
    private var chromeScale: CGFloat { 1 }
    #endif

    private var stackSpacing: CGFloat { 8 * chromeScale }
    private var horizontalPadding: CGFloat { 14 * chromeScale }
    private var verticalPadding: CGFloat { 9 * chromeScale }
    private var iconLabelSpacing: CGFloat { 5 * chromeScale }
    private var tabWidth: CGFloat { max(VPSpace.minTapTarget, 68 * chromeScale) }
    private var tabHeight: CGFloat { max(VPSpace.minTapTarget, 50 * chromeScale) }
    private var separatorHeight: CGFloat { 30 * chromeScale }
    private var separatorPadding: CGFloat { 3 * chromeScale }
    private var iconSize: CGFloat { 17 * chromeScale }
    private var textSize: CGFloat { 10 * chromeScale }
    private var badgeSize: CGFloat { 8 * chromeScale }
    private var containerInset: CGFloat { 4 * chromeScale }

    var body: some View {
        HStack(spacing: stackSpacing) {
            ForEach(SidebarTab.mainTabs, id: \.self) { tab in
                tabButton(tab: tab, isSelected: selectedTab == tab) {
                    switch BottomTabRoutingPolicy.action(
                        for: tab,
                        opensEnvironmentPicker: opensEnvironmentPicker
                    ) {
                    case .openEnvironmentPicker:
                        onOpenEnvironmentPicker()
                    case .select(let selected):
                        onTabSelection(selected)
                    }
                }
            }

            // Thin separator between main tabs and settings
            Capsule()
                .fill(.white.opacity(0.15))
                .frame(width: 1, height: separatorHeight)
                .padding(.horizontal, separatorPadding)

            tabButton(tab: .settings, isSelected: selectedTab == .settings) {
                onTabSelection(.settings)
            }
        }
        .padding(containerInset)
        .padding(.horizontal, horizontalPadding)
        .padding(.vertical, verticalPadding)
        .vpChromeSurface(.capsule)
    }

    private func tabButton(tab: SidebarTab, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: iconLabelSpacing) {
                ZStack(alignment: .topTrailing) {
                    Image(systemName: tab.icon)
                        .font(.system(size: iconSize, weight: isSelected ? .semibold : .medium))

                    // Badge dot
                    if TabBadgePolicy.shouldShowBadge(
                        for: tab,
                        activeDownloadCount: activeDownloadCount,
                        settingsWarningCount: settingsWarningCount
                    ) {
                        Circle()
                            .fill(TabBadgePolicy.badgeColor(for: tab))
                            .frame(width: badgeSize, height: badgeSize)
                            .offset(x: 4 * chromeScale, y: -2 * chromeScale)
                    }
                }

                Text(tab.rawValue)
                    .font(.system(size: textSize, weight: .medium))
            }
            .foregroundStyle(VPNavForeground.tint(isSelected: isSelected))
            .frame(width: tabWidth, height: tabHeight)
            #if os(macOS)
            .background {
                if !isSelected, hoveredTab == tab {
                    Capsule()
                        .fill(Color.white.opacity(0.12))
                }
            }
            #endif
            .vpNavItemSelection(isSelected: isSelected)
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(TabBarAccessibilityPolicy.accessibilityLabel(for: tab, isSelected: isSelected))
        .accessibilityHint(TabBarAccessibilityPolicy.accessibilityHint(for: tab))
        #if os(visionOS)
        .hoverEffect(.highlight)
        #else
        .onHover { isHovered in
            withAnimation(.easeInOut(duration: 0.15)) {
                hoveredTab = isHovered ? tab : nil
            }
        }
        #endif
        .animation(
            .spring(
                response: TabTransitionPolicy.springResponse,
                dampingFraction: TabTransitionPolicy.springDamping
            ),
            value: selectedTab
        )
    }
}

// MARK: - Environments Tab

#if os(visionOS)
struct EnvironmentsTabView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.openImmersiveSpace) private var openImmersiveSpace
    @Environment(\.dismissImmersiveSpace) private var dismissImmersiveSpace
    @State private var environments: [EnvironmentAsset] = []
    @State private var isLoading = true
    @State private var environmentLoadTask: Task<Void, Never>?
    @State private var installingPresetIDs: Set<String> = []
    @State private var environmentError: String?
    private let disablesAutomaticTasks: Bool
    private let onlinePresets = EnvironmentCatalogManager.onlinePresets

    init(
        initialEnvironments: [EnvironmentAsset] = [],
        initialIsLoading: Bool = true,
        disablesAutomaticTasks: Bool = false
    ) {
        _environments = State(initialValue: initialEnvironments)
        _isLoading = State(initialValue: initialIsLoading)
        self.disablesAutomaticTasks = disablesAutomaticTasks
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                environmentHeader

                if isLoading {
                    LoadingOverlay(
                        title: "Loading Environments",
                        message: "Fetching available environments\u{2026}"
                    )
                    .frame(maxWidth: .infinity)
                    .padding(.top, 60)
                } else {
                    environmentGrid

                    if environments.isEmpty {
                        importPrompt
                    }

                    environmentStatusPanel
                    onlinePresetsSection

                    if let environmentError {
                        environmentErrorBanner(environmentError)
                    }
                }
            }
            .frame(maxWidth: 1040, alignment: .leading)
            .padding(.horizontal, 28)
            .padding(.top, 22)
            .padding(.bottom, 128)
        }
        .background {
            VPBackground()
                .ignoresSafeArea()
        }
        .navigationTitle("Environments")
        .task {
            guard !disablesAutomaticTasks else { return }
            await coalescedLoadEnvironments()
        }
        .onReceive(NotificationCenter.default.publisher(for: .environmentsDidChange)) { _ in
            guard !disablesAutomaticTasks else { return }
            scheduleEnvironmentLoad()
        }
        .onDisappear {
            environmentLoadTask?.cancel()
            environmentLoadTask = nil
        }
    }

    private var environmentHeader: some View {
        HStack(alignment: .center, spacing: 18) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Playback Room")
                    .font(.title2.weight(.semibold))
                Text("Pick the room before playback, or leave it on the standard windowed room.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 16)

            VPBadge(
                text: environmentStatusBadgeText,
                systemImage: environmentStatusIconName,
                tint: appState.isImmersiveSpaceOpen ? .green : VPColor.textSecondary
            )
        }
    }

    private var environmentGrid: some View {
        let columns = [GridItem(.adaptive(minimum: 286, maximum: 340), spacing: 18)]
        return LazyVGrid(columns: columns, spacing: 18) {
            NoEnvironmentPreviewCard(
                status: EnvironmentPreviewRowPolicy.standardRoomStatus(
                    selectedAssetID: appState.selectedEnvironmentAsset?.id,
                    isImmersiveSpaceOpen: appState.isImmersiveSpaceOpen
                ),
                onSelect: { Task { await clearEnvironmentSelection() } }
            )

            CinemaEnvironmentPreviewCard(
                status: EnvironmentPreviewRowPolicy.cinemaStatus(
                    activeEnvironment: appState.activeEnvironment,
                    isImmersiveSpaceOpen: appState.isImmersiveSpaceOpen
                ),
                onSelect: { Task { await selectCinemaEnvironment() } }
            )

            ForEach(environments) { asset in
                EnvironmentPreviewCard(
                    asset: asset,
                    status: EnvironmentPreviewRowPolicy.assetStatus(
                        assetID: asset.id,
                        selectedAssetID: appState.selectedEnvironmentAsset?.id,
                        activeEnvironment: appState.activeEnvironment,
                        isImmersiveSpaceOpen: appState.isImmersiveSpaceOpen
                    ),
                    managedImportedAssetDirectory: appState.environmentCatalogManager.managedImportedAssetsDirectory,
                    onSelect: { Task { await selectEnvironment(asset) } }
                )
            }
        }
    }

    private var environmentStatusPanel: some View {
        HStack(alignment: .center, spacing: 14) {
            Image(systemName: environmentStatusIconName)
                .font(.title3.weight(.semibold))
                .foregroundStyle(appState.isImmersiveSpaceOpen ? .green : VPColor.textSecondary)
                .frame(width: 42, height: 42)
                .background(.white.opacity(0.06), in: Circle())

            VStack(alignment: .leading, spacing: 3) {
                Text(environmentStatusTitle)
                    .font(.headline)
                Text(environmentStatusDescription)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .layoutPriority(1)

            Spacer(minLength: 12)

            if appState.isImmersiveSpaceOpen || appState.selectedEnvironmentAsset != nil {
                Button(role: appState.isImmersiveSpaceOpen ? .destructive : nil) {
                    Task { await clearEnvironmentSelection() }
                } label: {
                    Label(
                        appState.isImmersiveSpaceOpen ? "Exit Environment" : "Standard Room",
                        systemImage: appState.isImmersiveSpaceOpen ? "xmark.circle" : "rectangle.dashed"
                    )
                }
                .buttonStyle(VPButtonStyle(kind: appState.isImmersiveSpaceOpen ? .destructive : .secondary))
            }
        }
        .padding(16)
        .glassSurface(.raised, cornerRadius: 18)
    }

    @ViewBuilder
    private var onlinePresetsSection: some View {
        if !onlinePresets.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("More Environments")
                        .font(.headline)
                    Text("Add curated HDRI rooms, then select the card above before playback.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                ForEach(onlinePresets) { preset in
                    onlinePresetRow(preset)
                }
            }
        }
    }

    private func onlinePresetRow(_ preset: CuratedEnvironmentPreset) -> some View {
        let isInstalled = isPresetInstalled(preset)
        let isInstalling = installingPresetIDs.contains(preset.id)

        return HStack(alignment: .center, spacing: 14) {
            Image(systemName: EnvironmentPreviewRowPolicy.providerIconName(for: preset.provider))
                .font(.title3.weight(.semibold))
                .foregroundStyle(.secondary)
                .frame(width: 38, height: 38)
                .background(.white.opacity(0.06), in: Circle())

            VStack(alignment: .leading, spacing: 3) {
                Text(preset.name)
                    .font(.subheadline.weight(.semibold))
                Text(preset.description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                Text("\(preset.provider.displayName) • \(preset.licenseName)")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            .layoutPriority(1)

            Spacer(minLength: 12)

            if isInstalled {
                Label("Added", systemImage: "checkmark.circle.fill")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(VPColor.success)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                    .background(VPColor.success.opacity(0.12), in: Capsule())
            } else {
                Button {
                    Task { await installPreset(preset) }
                } label: {
                    if isInstalling {
                        HStack(spacing: 8) {
                            ProgressView()
                                .controlSize(.small)
                            Text("Adding")
                        }
                    } else {
                        Label("Add", systemImage: "arrow.down.circle")
                    }
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .frame(minWidth: 82)
                .disabled(isInstalling)
            }
        }
        .padding(14)
        .glassSurface(.raised, cornerRadius: 14)
    }

    private func environmentErrorBanner(_ message: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.yellow)
            Text(message)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(3)
            Spacer(minLength: 12)
            Button("Dismiss") { environmentError = nil }
                .font(.caption)
        }
        .padding(12)
        .glassSurface(.raised, cornerRadius: 12)
    }

    private var environmentStatusTitle: String {
        if appState.isImmersiveSpaceOpen {
            if appState.activeEnvironment == .cinemaEnvironment {
                return "Cinema Environment is active"
            }
            if let selected = appState.selectedEnvironmentAsset {
                return "\(selected.name) is active"
            }
            return "Environment is active"
        }

        if let selected = appState.selectedEnvironmentAsset {
            return "\(selected.name) is selected"
        }

        return "Standard Room"
    }

    private var environmentStatusDescription: String {
        if appState.isImmersiveSpaceOpen {
            return "This room is currently open. Exit it before switching back to the standard room."
        }

        if appState.selectedEnvironmentAsset != nil {
            return "The selected room will open when playback starts."
        }

        return "No immersive environment is selected."
    }

    private var environmentStatusBadgeText: String {
        if appState.isImmersiveSpaceOpen {
            return "Active"
        }

        if appState.selectedEnvironmentAsset != nil {
            return "Selected"
        }

        return "Standard"
    }

    private var environmentStatusIconName: String {
        if appState.activeEnvironment == .cinemaEnvironment {
            return "theatermasks"
        }
        if appState.selectedEnvironmentAsset != nil {
            return "mountain.2"
        }
        return "rectangle.dashed"
    }

    private var importPrompt: some View {
        HStack(spacing: 16) {
            Image(systemName: "mountain.2")
                .font(.system(size: 30, weight: .semibold))
                .foregroundStyle(.secondary)
                .frame(width: 44, height: 44)

            VStack(alignment: .leading, spacing: 4) {
                Text("No imported environments")
                    .font(.headline)
                Text("Add a curated room below, or import your own files from Settings.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 16)

            Button {
                appState.selectedTab = .settings
            } label: {
                Label("Open Settings", systemImage: "slider.horizontal.3")
            }
            .buttonStyle(VPButtonStyle(kind: .secondary))
        }
        .frame(maxWidth: .infinity)
        .padding(18)
        .glassSurface(.raised, cornerRadius: 18)
    }

    @MainActor
    private func scheduleEnvironmentLoad() {
        environmentLoadTask?.cancel()
        environmentLoadTask = Task { await loadEnvironments() }
    }

    @MainActor
    private func coalescedLoadEnvironments() async {
        scheduleEnvironmentLoad()
        await environmentLoadTask?.value
    }

    @MainActor
    private func loadEnvironments() async {
        isLoading = true
        let latestEnvironments = (try? await appState.environmentCatalogManager.fetchAssets()) ?? []
        guard !Task.isCancelled else { return }
        environments = latestEnvironments
        isLoading = false
    }

    private func isPresetInstalled(_ preset: CuratedEnvironmentPreset) -> Bool {
        environments.contains { environment in
            environment.sourceType == .imported
                && environment.name == preset.name
                && environment.sourceAttributionURL == preset.sourceAttributionURL
        }
    }

    @MainActor
    private func installPreset(_ preset: CuratedEnvironmentPreset) async {
        guard !isPresetInstalled(preset),
              !installingPresetIDs.contains(preset.id) else {
            return
        }

        environmentError = nil
        installingPresetIDs.insert(preset.id)
        defer { installingPresetIDs.remove(preset.id) }

        do {
            _ = try await appState.environmentCatalogManager.importCuratedPreset(preset)
            await coalescedLoadEnvironments()
        } catch {
            environmentError = error.localizedDescription
        }
    }

    private func selectEnvironment(_ asset: EnvironmentAsset) async {
        if asset.id == appState.selectedEnvironmentAsset?.id, appState.isImmersiveSpaceOpen {
            guard await exitEnvironment() else {
                environmentError = PlayerImmersiveTransitionPolicy.transitionBusyMessage
                return
            }
            return
        }
        guard await ensureImportedEnvironmentAssetExists(asset) else {
            environmentError = PlayerImmersiveTransitionPolicy.missingAssetMessage(assetName: asset.name)
            await coalescedLoadEnvironments()
            return
        }
        if appState.isImmersiveSpaceOpen {
            guard appState.beginImmersiveTransition() else {
                environmentError = PlayerImmersiveTransitionPolicy.transitionBusyMessage
                return
            }
            appState.stageImmersiveDismiss(reason: .switchingEnvironment)
            await dismissImmersiveSpace()
            appState.completeImmersiveDismissIfStillPending()
        }
        guard await appState.activateEnvironmentAsset(asset) else {
            environmentError = PlayerImmersiveTransitionPolicy.missingAssetMessage(assetName: asset.name)
            await coalescedLoadEnvironments()
            return
        }
        guard appState.beginImmersiveTransition() else {
            await appState.clearEnvironmentSelectionIfCurrent(assetID: asset.id)
            environmentError = PlayerImmersiveTransitionPolicy.transitionBusyMessage
            await coalescedLoadEnvironments()
            return
        }
        let spaceID = await appState.environmentCatalogManager.immersiveSpaceID(for: asset)
        let result = await openImmersiveSpace(id: spaceID)
        switch result {
        case .opened: break
        case .error, .userCancelled:
            appState.cancelImmersiveTransition()
            await appState.clearEnvironmentSelectionIfCurrent(assetID: asset.id)
            environmentError = PlayerImmersiveTransitionPolicy.openFailedMessage(assetName: asset.name)
            await coalescedLoadEnvironments()
        @unknown default:
            appState.cancelImmersiveTransition()
            await appState.clearEnvironmentSelectionIfCurrent(assetID: asset.id)
            environmentError = PlayerImmersiveTransitionPolicy.openFailedMessage(assetName: asset.name)
            await coalescedLoadEnvironments()
        }
    }

    private func ensureImportedEnvironmentAssetExists(_ asset: EnvironmentAsset) async -> Bool {
        guard asset.sourceType == .imported else { return true }
        if await appState.environmentCatalogManager.resolvedAssetURL(for: asset) != nil {
            return true
        }

        try? await appState.environmentCatalogManager.deleteAsset(id: asset.id)
        await appState.clearEnvironmentSelectionIfCurrent(assetID: asset.id)
        return false
    }

    private func selectCinemaEnvironment() async {
        if appState.activeEnvironment == .cinemaEnvironment, appState.isImmersiveSpaceOpen {
            guard await exitEnvironment() else {
                environmentError = PlayerImmersiveTransitionPolicy.transitionBusyMessage
                return
            }
            return
        }
        if appState.isImmersiveSpaceOpen {
            guard appState.beginImmersiveTransition() else {
                environmentError = PlayerImmersiveTransitionPolicy.transitionBusyMessage
                return
            }
            appState.stageImmersiveDismiss(reason: .switchingEnvironment)
            await dismissImmersiveSpace()
            appState.completeImmersiveDismissIfStillPending()
        }
        guard appState.beginImmersiveTransition() else {
            environmentError = PlayerImmersiveTransitionPolicy.transitionBusyMessage
            return
        }
        let result = await openImmersiveSpace(id: EnvironmentType.cinemaEnvironment.immersiveSpaceId)
        switch result {
        case .opened: break
        case .error, .userCancelled:
            appState.cancelImmersiveTransition()
        @unknown default:
            appState.cancelImmersiveTransition()
        }
    }

    @discardableResult
    private func exitEnvironment() async -> Bool {
        guard appState.isImmersiveSpaceOpen else { return true }
        guard appState.beginImmersiveTransition() else { return false }
        appState.stageImmersiveDismiss(reason: .userInitiated)
        await dismissImmersiveSpace()
        appState.completeImmersiveDismissIfStillPending()
        return true
    }

    private func clearEnvironmentSelection() async {
        if appState.isImmersiveSpaceOpen {
            guard await exitEnvironment() else {
                environmentError = PlayerImmersiveTransitionPolicy.transitionBusyMessage
                return
            }
        }
        await appState.clearEnvironmentSelection()
        await coalescedLoadEnvironments()
    }
}
#else
struct EnvironmentsTabView: View {
    var body: some View {
        Text("Environments are available on Vision Pro.")
            .font(.title3)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
#endif
