import SwiftUI

enum SettingsNavigationInteractionPolicy {
    static func persistedDestinationRawValue(for destination: SettingsDestination) -> String {
        destination.rawValue
    }
}

enum SettingsRootLayoutPolicy {
    static let bottomContentPadding: CGFloat = 320
    static let bottomViewportInset: CGFloat = 260
}

struct SettingsView: View {
    @Environment(AppState.self) private var appState

    @State private var query = ""
    @State private var didLoadInitialSearch = false
    @State private var isRefreshingStatuses = false
    @State private var destinationStatuses: [SettingsDestination: SettingsDestinationStatus] = [:]
    @State private var isShowingResetSheet = false
    @State private var didTriggerQAAutoReset = false
    private let seededRecentDestination: SettingsDestination?
    private let disablesAutomaticTasks: Bool

    @AppStorage(VPDesignFlags.useObsidianGlassKey) private var useObsidianGlass = true
    @AppStorage("settings.last_destination") private var lastDestinationRawValue = ""
    @AppStorage("settings.search_query") private var persistedSearchQuery = ""
    @AppStorage(VPMenuBackgroundIntensityPolicy.appStorageKey)
    private var menuBackgroundIntensityRaw = VPMenuBackgroundIntensityPolicy.defaultValue

    private var filteredGroups: [SettingsDestinationGroup] {
        SettingsNavigationCatalog.groups(matching: query)
    }

    private var menuBackgroundIntensity: Binding<Double> {
        Binding(
            get: { SettingsAppearancePolicy.normalizedMenuBackgroundIntensity(menuBackgroundIntensityRaw) },
            set: { menuBackgroundIntensityRaw = SettingsAppearancePolicy.normalizedMenuBackgroundIntensity($0) }
        )
    }

    private var recentDestination: SettingsDestination? {
        seededRecentDestination ?? SettingsNavigationCatalog.destination(from: lastDestinationRawValue)
    }

    private var indicatorStatuses: [SettingsRowIndicatorPolicy.StatusKind] {
        destinationStatuses.values.map { SettingsRowIndicatorPolicy.statusKind(from: $0.kind) }
    }

    private var warningCount: Int {
        SettingsHealthPolicy.warningCount(statuses: indicatorStatuses)
    }

    private var configuredCount: Int {
        SettingsHealthPolicy.essentialConfiguredCount(statuses: destinationStatuses)
    }

    private var totalCount: Int {
        SettingsHealthPolicy.essentialTotal
    }

    private var healthProgress: Double {
        SettingsHealthPolicy.configurationProgress(configured: configuredCount, total: totalCount)
    }

    private var healthTint: Color {
        if healthProgress >= 0.75 { return .green }
        if healthProgress >= 0.45 { return .orange }
        return .yellow
    }

    init(
        initialQuery: String = "",
        initialDidLoadInitialSearch: Bool = false,
        initialIsRefreshingStatuses: Bool = false,
        initialDestinationStatuses: [SettingsDestination: SettingsDestinationStatus] = [:],
        initialIsShowingResetSheet: Bool = false,
        initialRecentDestination: SettingsDestination? = nil,
        disablesAutomaticTasks: Bool = false
    ) {
        _query = State(initialValue: initialQuery)
        _didLoadInitialSearch = State(initialValue: initialDidLoadInitialSearch)
        _isRefreshingStatuses = State(initialValue: initialIsRefreshingStatuses)
        _destinationStatuses = State(initialValue: initialDestinationStatuses)
        _isShowingResetSheet = State(initialValue: initialIsShowingResetSheet)
        self.seededRecentDestination = initialRecentDestination
        self.disablesAutomaticTasks = disablesAutomaticTasks
    }

    private var legacyBody: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 10) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Configuration Health")
                                .font(.subheadline.weight(.semibold))
                            Text(SettingsHealthPolicy.progressLabel(configured: configuredCount, total: totalCount))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        if SettingsHealthPolicy.shouldShowWarningBadge(warningCount: warningCount) {
                            GlassTag(
                                text: "\(warningCount) warning\(warningCount == 1 ? "" : "s")",
                                tintColor: .orange,
                                symbol: "exclamationmark.triangle"
                            )
                        }
                    }

                    GlassProgressBar(progress: healthProgress, tint: healthTint)
                }
                .padding(.vertical, 4)
            }

            if let recentDestination, recentDestination.matches(normalizedQuery) {
                Section("Continue") {
                    destinationLink(for: recentDestination, isRecent: true)
                }
            }

            if SettingsSearchPolicy.shouldShowEmptyState(
                resultCount: filteredGroups.flatMap(\.destinations).count,
                query: query
            ) {
                Section {
                    ContentUnavailableView(
                        "No Matching Settings",
                        systemImage: "magnifyingglass",
                        description: Text(SettingsSearchPolicy.resultsSummary(count: 0, query: query))
                    )
                    .padding(.vertical, 20)
                }
            } else {
                ForEach(filteredGroups) { group in
                    Section {
                        ForEach(group.destinations) { destination in
                            destinationLink(for: destination, isRecent: false)
                        }
                    } header: {
                        SettingsSectionHeader(
                            category: group.category,
                            configuredCount: configuredCountForCategory(group.category),
                            totalCount: group.destinations.count
                        )
                    }
                }
            }

            Section("Appearance") {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Label("Menu Background Intensity", systemImage: "circle.lefthalf.filled")
                        Spacer()
                        Text(SettingsAppearancePolicy.menuBackgroundIntensityLabel(for: menuBackgroundIntensity.wrappedValue))
                            .font(.caption)
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                    }

                    Slider(value: menuBackgroundIntensity, in: VPMenuBackgroundIntensityPolicy.range)
                        .accessibilityLabel("Menu background intensity")
                        .accessibilityValue(SettingsAppearancePolicy.menuBackgroundIntensityLabel(for: menuBackgroundIntensity.wrappedValue))
                        .accessibilityHint("Adjusts the strength of the cinematic menu background.")
                }
                .padding(.vertical, 4)
            }

            Section("Quick Actions") {
                Button {
                    appState.isShowingSetup = true
                } label: {
                    Label("Run Setup Wizard", systemImage: "wand.and.stars")
                }

                Button {
                    Task { await refreshStatuses() }
                } label: {
                    if isRefreshingStatuses {
                        Label("Refreshing…", systemImage: "arrow.clockwise")
                    } else {
                        Label("Refresh Configuration Status", systemImage: "arrow.clockwise")
                    }
                }
                .disabled(isRefreshingStatuses)
            }

            Section("About") {
                infoRow(title: "Version", value: appVersion)
                infoRow(title: "Build", value: appBuild)
            }

            Section {
                Button(role: .destructive) {
                    isShowingResetSheet = true
                } label: {
                    Label("Reset All Data", systemImage: "trash")
                        .foregroundStyle(.red)
                }
            } footer: {
                Text("Permanently erases all settings, credentials, downloads, and local data.")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .scrollContentBackground(.hidden)
        .background {
            VPMenuBackground()
                .ignoresSafeArea()
        }
    }

    var body: some View {
        Group {
            if useObsidianGlass {
                obsidianBody
            } else {
                legacyBody
            }
        }
        // Obsidian provides its own hero title via VPPageShell; empty the system nav title to
        // avoid a duplicate while keeping the searchable field.
        .navigationTitle(useObsidianGlass ? "" : "Settings")
        .sheet(isPresented: $isShowingResetSheet) {
            ResetDataView()
        }
        .navigationDestination(for: SettingsDestination.self) { destination in
            destinationView(for: destination)
                .onAppear {
                    lastDestinationRawValue = SettingsNavigationInteractionPolicy.persistedDestinationRawValue(
                        for: destination
                    )
                }
        }
        .searchable(text: $query, prompt: "Search settings")
        .task {
            guard !disablesAutomaticTasks else {
                didLoadInitialSearch = true
                return
            }
            if !didLoadInitialSearch {
                query = persistedSearchQuery
                didLoadInitialSearch = true
            }
            await refreshStatuses()
            if QARuntimeOptions.autoOpenResetSheet, !didTriggerQAAutoReset {
                didTriggerQAAutoReset = true
                isShowingResetSheet = true
            }
        }
        .refreshable {
            await refreshStatuses()
        }
        .onChange(of: query) { _, newValue in
            persistedSearchQuery = newValue
        }
        .onReceive(NotificationCenter.default.publisher(for: .metadataApiKeyDidChange)) { _ in
            Task { await refreshStatuses() }
        }
        .onReceive(NotificationCenter.default.publisher(for: .indexersDidChange)) { _ in
            Task { await refreshStatuses() }
        }
        .onReceive(NotificationCenter.default.publisher(for: .environmentsDidChange)) { _ in
            Task { await refreshStatuses() }
        }
        .onReceive(NotificationCenter.default.publisher(for: .localModelsDidChange)) { _ in
            Task { await refreshStatuses() }
        }
        .onReceive(NotificationCenter.default.publisher(for: .openSubtitlesDidChange)) { _ in
            Task { await refreshStatuses() }
        }
        .onReceive(NotificationCenter.default.publisher(for: .settingsDidChange)) { _ in
            Task { await refreshStatuses() }
        }
        .onReceive(NotificationCenter.default.publisher(for: .appDidResetAllData)) { _ in
            query = ""
            persistedSearchQuery = ""
            lastDestinationRawValue = ""
            didLoadInitialSearch = false
            isShowingResetSheet = false
            Task { await refreshStatuses() }
        }
    }

    // MARK: - Obsidian Glass body

    private var obsidianBody: some View {
        VPPageShell(
            title: "Settings",
            bottomContentPadding: SettingsRootLayoutPolicy.bottomContentPadding,
            bottomViewportInset: SettingsRootLayoutPolicy.bottomViewportInset
        ) {
            obsidianHealthCard

            if let recentDestination, recentDestination.matches(normalizedQuery) {
                obsidianSection("Continue", icon: "clock.arrow.circlepath") {
                    obsidianDestinationLink(recentDestination, isRecent: true)
                }
            }

            if SettingsSearchPolicy.shouldShowEmptyState(
                resultCount: filteredGroups.flatMap(\.destinations).count,
                query: query
            ) {
                VPStateCard(
                    systemImage: "magnifyingglass",
                    title: "No Matching Settings",
                    message: SettingsSearchPolicy.resultsSummary(count: 0, query: query)
                )
                .frame(maxWidth: .infinity)
            } else {
                ForEach(filteredGroups) { group in
                    obsidianSection(
                        group.category.title,
                        icon: categoryIcon(group.category),
                        badge: "\(configuredCountForCategory(group.category))/\(group.destinations.count) set up"
                    ) {
                        ForEach(Array(group.destinations.enumerated()), id: \.element.id) { index, destination in
                            obsidianDestinationLink(destination, isRecent: false)
                            if index < group.destinations.count - 1 {
                                Divider().overlay(VPColor.specularDim).padding(.leading, 72)
                            }
                        }
                    }
                }
            }

            obsidianSection("Appearance", icon: "circle.lefthalf.filled") {
                obsidianAppearanceCardContent
            }

            obsidianSection("Quick Actions", icon: "bolt.fill") {
                HStack(spacing: VPSpace.snug) {
                    Button { appState.isShowingSetup = true } label: {
                        Label("Run Setup", systemImage: "wand.and.stars")
                    }
                    .buttonStyle(VPButtonStyle(kind: .secondary))

                    Button { Task { await refreshStatuses() } } label: {
                        Label(isRefreshingStatuses ? "Refreshing…" : "Refresh Status",
                              systemImage: "arrow.clockwise")
                    }
                    .buttonStyle(VPButtonStyle(kind: .secondary))
                    .disabled(isRefreshingStatuses)
                }
                .padding(VPSpace.snug)
            }

            obsidianSection("About", icon: "info.circle") {
                obsidianAboutRow("Version", appVersion)
                Divider().overlay(VPColor.specularDim).padding(.leading, VPSpace.normal)
                obsidianAboutRow("Build", appBuild)
            }

            VPCard(elevation: .raised) {
                VStack(alignment: .leading, spacing: VPSpace.snug) {
                    Button { isShowingResetSheet = true } label: {
                        Label("Reset All Data", systemImage: "trash")
                    }
                    .buttonStyle(VPButtonStyle(kind: .destructive))

                    Text("Permanently erases all settings, credentials, downloads, and local data.")
                        .font(VPFont.caption)
                        .foregroundStyle(VPColor.textTertiary)
                }
            }
        }
    }

    private var obsidianHealthCard: some View {
        VPCard(elevation: .raised) {
            VStack(alignment: .leading, spacing: VPSpace.normal) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Configuration Health")
                            .font(VPFont.title2)
                            .foregroundStyle(VPColor.textPrimary)
                        Text(SettingsHealthPolicy.progressLabel(configured: configuredCount, total: totalCount))
                            .font(VPFont.caption)
                            .foregroundStyle(VPColor.textSecondary)
                    }
                    Spacer()
                    if SettingsHealthPolicy.shouldShowWarningBadge(warningCount: warningCount) {
                        VPBadge(
                            text: "\(warningCount) warning\(warningCount == 1 ? "" : "s")",
                            systemImage: "exclamationmark.triangle",
                            tint: VPColor.warning
                        )
                    }
                }
                VPProgressBar(value: healthProgress, height: 10, tint: healthTintToken)
            }
        }
    }

    @ViewBuilder
    private var obsidianAppearanceCardContent: some View {
        VStack(alignment: .leading, spacing: VPSpace.snug) {
            HStack {
                Label("Menu Background Intensity", systemImage: "circle.lefthalf.filled")
                    .font(VPFont.body)
                    .foregroundStyle(VPColor.textPrimary)
                Spacer()
                Text(SettingsAppearancePolicy.menuBackgroundIntensityLabel(for: menuBackgroundIntensity.wrappedValue))
                    .font(VPFont.caption)
                    .monospacedDigit()
                    .foregroundStyle(VPColor.textSecondary)
            }
            Slider(value: menuBackgroundIntensity, in: VPMenuBackgroundIntensityPolicy.range)
                .tint(VPColor.accent)
                .accessibilityLabel("Menu background intensity")
                .accessibilityValue(SettingsAppearancePolicy.menuBackgroundIntensityLabel(for: menuBackgroundIntensity.wrappedValue))
                .accessibilityHint("Adjusts the strength of the cinematic menu background.")
        }
        .padding(VPSpace.snug)
    }

    @ViewBuilder
    private func obsidianSection<Content: View>(
        _ title: String,
        icon: String,
        badge: String? = nil,
        @ViewBuilder content: @escaping () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: VPSpace.snug) {
            HStack(spacing: VPSpace.snug) {
                VPSectionBadge(systemImage: icon)
                VPSectionHeader(title: title)
                if let badge {
                    VPBadge(text: badge)
                        .accessibilityLabel(badge)
                }
            }
            VPCard(padding: VPSpace.tight) {
                VStack(spacing: 0) { content() }
            }
        }
    }

    private func obsidianDestinationLink(_ destination: SettingsDestination, isRecent: Bool) -> some View {
        NavigationLink(value: destination) {
            VPRow(destination.title, subtitle: destination.summary, systemImage: destination.icon, iconTint: destination.tintColor) {
                HStack(spacing: VPSpace.tight) {
                    if isRecent { VPBadge(text: "Recent", tint: VPColor.accent) }
                    if let status = destinationStatuses[destination], !status.message.isEmpty {
                        GlassTag(text: status.message, tintColor: statusColor(status.kind))
                            .accessibilityHidden(true) // status conveyed via the row's hint
                    }
                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(VPColor.textTertiary)
                        .accessibilityHidden(true)
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityHint(destinationStatuses[destination]?.message ?? "")
    }

    private func obsidianAboutRow(_ title: String, _ value: String) -> some View {
        HStack {
            Text(title).font(VPFont.body).foregroundStyle(VPColor.textPrimary)
            Spacer()
            Text(value).font(VPFont.body).monospacedDigit().foregroundStyle(VPColor.textSecondary)
        }
        .padding(.horizontal, VPSpace.normal)
        .frame(minHeight: 52)
    }

    private func statusColor(_ kind: SettingsStatusKind) -> Color {
        switch kind {
        case .positive: return VPColor.success
        case .warning:  return VPColor.warning
        case .neutral:  return VPColor.textTertiary
        }
    }

    private func categoryIcon(_ category: SettingsCategory) -> String {
        switch category {
        case .connect:  return "link"
        case .watch:    return "play.rectangle"
        case .discover: return "safari"
        case .library:  return "books.vertical"
        case .about:    return "info.circle"
        }
    }

    private var healthTintToken: Color {
        if healthProgress >= 0.75 { return VPColor.success }
        if healthProgress >= 0.45 { return VPColor.warning }
        return .yellow
    }

    private var normalizedQuery: String {
        query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    private var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0.0"
    }

    private var appBuild: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"
    }

    @ViewBuilder
    private func destinationView(for destination: SettingsDestination) -> some View {
        switch destination {
        case .debrid:
            DebridSettingsView()
        case .debridCloud:
            DebridCloudView()
        case .indexers:
            IndexerSettingsView()
        case .metadata:
            MetadataSettingsView()
        case .ai:
            AISettingsView()
        case .trakt:
            TraktSettingsView()
        case .simkl:
            SimklSettingsView()
        case .imdbImport:
            IMDbImportSettingsView()
        case .player:
            PlayerSettingsView()
        case .subtitles:
            SubtitleSettingsView()
        case .environments:
            EnvironmentSettingsView()
        case .library:
            LibraryView()
        case .downloads:
            DownloadsView()
        case .resetData:
            ResetDataView()
        case .testMode:
            TestModeView()
        }
    }

    private func destinationLink(for destination: SettingsDestination, isRecent: Bool) -> some View {
        NavigationLink(value: destination) {
            SettingsDestinationRow(
                destination: destination,
                status: destinationStatuses[destination],
                isRecent: isRecent
            )
        }
        .buttonStyle(.plain)
    }

    private func configuredCountForCategory(_ category: SettingsCategory) -> Int {
        SettingsNavigationCatalog.orderedDestinations
            .filter { $0.category == category }
            .filter { destination in
                destinationStatuses[destination]?.kind == .positive
            }
            .count
    }

    private func infoRow(title: String, value: String) -> some View {
        HStack {
            Text(title)
            Spacer()
            Text(value)
                .foregroundStyle(.secondary)
        }
    }

    @MainActor
    private func refreshStatuses() async {
        isRefreshingStatuses = true
        let snapshot = await captureStatusSnapshot()
        var nextStatuses: [SettingsDestination: SettingsDestinationStatus] = [:]
        for destination in SettingsNavigationCatalog.orderedDestinations {
            nextStatuses[destination] = SettingsStatusFormatter.status(for: destination, snapshot: snapshot)
        }
        destinationStatuses = nextStatuses
        isRefreshingStatuses = false
    }

    private func captureStatusSnapshot() async -> SettingsStatusSnapshot {
        var snapshot = SettingsStatusSnapshot()

        if let configs = try? await appState.database.fetchAllDebridConfigs() {
            snapshot.activeDebridCount = configs.filter(\.isActive).count
        }

        if let configs = try? await appState.database.fetchAllIndexerConfigs() {
            snapshot.activeIndexerCount = configs.filter(\.isActive).count
        }

        if let configuration = try? await appState.settingsManager.getMetadataProviderConfiguration() {
            snapshot.hasMetadataKey = configuration.isConfigured
            snapshot.metadataProviderSummary = configuration.isConfigured ? configuration.providerSummary : nil
        } else {
            snapshot.hasMetadataKey = false
            snapshot.metadataProviderSummary = nil
        }
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
        let userTraktClient = try? await appState.settingsManager.getString(key: SettingsKeys.traktClientId)
        let userTraktSecret = try? await appState.settingsManager.getString(key: SettingsKeys.traktClientSecret)
        snapshot.hasTraktCredentials = TraktDefaults.resolvedCredentials(
            userClientId: userTraktClient,
            userClientSecret: userTraktSecret
        ) != nil
        let hasTraktAccessToken = await hasNonEmptyString(for: SettingsKeys.traktAccessToken)
        snapshot.hasTraktConnection = snapshot.hasTraktCredentials && hasTraktAccessToken

        let hasSimklClient = await hasNonEmptyString(for: SettingsKeys.simklClientId)
        let hasSimklToken = await hasNonEmptyString(for: SettingsKeys.simklAccessToken)
        snapshot.hasSimklCredentials = hasSimklClient && hasSimklToken

        return snapshot
    }

    private func hasNonEmptyString(for key: String, fallback: String? = nil) async -> Bool {
        let value = (try? await appState.settingsManager.getString(key: key)) ?? fallback
        return !(value?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true)
    }
}
