import SwiftUI

enum DownloadsLoadingSurfacePolicy {
    static let title = "Loading Downloads"
    static let message = "Checking progress, completed titles, and offline availability."

    static func shouldShowRootLoading(
        hasViewModel: Bool,
        isLoading: Bool,
        groupCount: Int
    ) -> Bool {
        !hasViewModel || (isLoading && groupCount == 0)
    }
}

enum DownloadsErrorSurfaceMode: Equatable {
    case none
    case rootError
    case inlineError
}

enum DownloadsErrorSurfacePolicy {
    static func presentationMode(
        groupCount: Int,
        hasRootError: Bool
    ) -> DownloadsErrorSurfaceMode {
        guard hasRootError else { return .none }
        return groupCount == 0 ? .rootError : .inlineError
    }
}

struct DownloadsView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.openWindow) private var openWindow
    @State private var viewModel: DownloadsViewModel?
    @State private var reloadTask: Task<Void, Never>?
    @State private var confirmDeleteMediaId: String?
    @State private var confirmDeleteTaskID: String?
    @State private var playbackValidationMessage: String?
    @State private var didPerformQADownloadAction = false
    @AppStorage(VPDesignFlags.useObsidianGlassKey) private var useObsidianGlass = true
    private let disablesAutomaticTasks: Bool

    init(
        viewModel: DownloadsViewModel? = nil,
        initialConfirmDeleteMediaId: String? = nil,
        initialConfirmDeleteTaskID: String? = nil,
        initialPlaybackValidationMessage: String? = nil,
        disablesAutomaticTasks: Bool = false
    ) {
        _viewModel = State(initialValue: viewModel)
        _confirmDeleteMediaId = State(initialValue: initialConfirmDeleteMediaId)
        _confirmDeleteTaskID = State(initialValue: initialConfirmDeleteTaskID)
        _playbackValidationMessage = State(initialValue: initialPlaybackValidationMessage)
        self.disablesAutomaticTasks = disablesAutomaticTasks
    }

    private var shouldShowRootLoadingSurface: Bool {
        DownloadsLoadingSurfacePolicy.shouldShowRootLoading(
            hasViewModel: viewModel != nil,
            isLoading: viewModel?.isLoading ?? true,
            groupCount: viewModel?.groups.count ?? 0
        )
    }

    private func errorSurfaceMode(for vm: DownloadsViewModel) -> DownloadsErrorSurfaceMode {
        DownloadsErrorSurfacePolicy.presentationMode(
            groupCount: vm.groups.count,
            hasRootError: vm.rootError != nil
        )
    }

    private var legacyRoot: some View {
        Group {
            if shouldShowRootLoadingSurface {
                VStack {
                    Spacer()
                    LoadingOverlay(
                        title: DownloadsLoadingSurfacePolicy.title,
                        message: DownloadsLoadingSurfacePolicy.message
                    )
                    Spacer()
                }
            } else if let vm = viewModel {
                content(vm)
            } else {
                EmptyView()
            }
        }
        .background {
            VPMenuBackground()
                .ignoresSafeArea()
        }
    }

    var body: some View {
        Group {
            if useObsidianGlass {
                obsidianRoot
            } else {
                legacyRoot
            }
        }
        .navigationTitle(useObsidianGlass ? "" : "Downloads")
        .alert(
            "Download Unavailable",
            isPresented: Binding(
                get: { playbackValidationMessage != nil },
                set: { if !$0 { playbackValidationMessage = nil } }
            )
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(playbackValidationMessage ?? "The downloaded file is no longer available.")
        }
        .task {
            guard !disablesAutomaticTasks else { return }
            if viewModel == nil {
                let vm = DownloadsViewModel(appState: appState)
                viewModel = vm
                await vm.load()
                await performQADownloadActionIfNeeded(vm)
            }
        }
        .onDisappear {
            reloadTask?.cancel()
            reloadTask = nil
        }
        .onReceive(NotificationCenter.default.publisher(for: .downloadsDidChange)) { _ in
            guard !disablesAutomaticTasks else { return }
            guard let vm = viewModel else { return }
            reloadTask?.cancel()
            reloadTask = Task {
                await vm.load()
                await performQADownloadActionIfNeeded(vm)
            }
        }
    }

    // MARK: - Obsidian Glass

    private var obsidianRoot: some View {
        ZStack {
            VPBackground()
            if shouldShowRootLoadingSurface {
                LoadingOverlay(
                    title: DownloadsLoadingSurfacePolicy.title,
                    message: DownloadsLoadingSurfacePolicy.message
                )
            } else if let vm = viewModel {
                obsidianContent(vm)
            } else {
                Color.clear
            }
        }
    }

    @ViewBuilder
    private func obsidianContent(_ vm: DownloadsViewModel) -> some View {
        switch errorSurfaceMode(for: vm) {
        case .rootError:
            if let error = vm.rootError {
                obsidianStateSurface(
                    icon: "exclamationmark.triangle",
                    title: error.errorDescription ?? "Downloads couldn’t load right now.",
                    message: error.recoverySuggestion,
                    tint: VPColor.warning,
                    actionTitle: "Retry"
                ) { retryRootLoad(vm) }
            }
        case .inlineError, .none:
            if vm.groups.isEmpty {
                obsidianStateSurface(
                    icon: "arrow.down.circle",
                    title: "Build your offline shelf",
                    message: "Downloaded movies and episodes show up here with progress, retry, and one-tap playback. Grab a title from Discover, then download the stream you want to keep.",
                    tint: VPColor.info,
                    actionTitle: "Browse Discover"
                ) { appState.selectedTab = .discover }
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: VPSpace.roomy) {
                        HStack(alignment: .firstTextBaseline) {
                            Text("Downloads")
                                .font(VPFont.title1)
                                .foregroundStyle(VPColor.textPrimary)
                                .accessibilityAddTraits(.isHeader)
                            Spacer()
                            downloadsMenu(vm)
                        }

                        if case .inlineError = errorSurfaceMode(for: vm), let error = vm.rootError {
                            obsidianInlineErrorBanner(error, vm: vm)
                        }

                        downloadsSummaryCard(vm)

                        if !vm.activeGroups.isEmpty {
                            downloadsSectionHeader("Active", systemImage: "arrow.down.circle.fill", count: vm.activeTaskCount)
                            LazyVStack(spacing: VPSpace.roomy) {
                                ForEach(vm.activeGroups) { obsidianGroupCard($0, vm: vm) }
                            }
                        }

                        if !vm.completedGroups.isEmpty {
                            downloadsSectionHeader("Downloaded", systemImage: "checkmark.circle.fill", count: vm.completedGroups.count)
                            LazyVStack(spacing: VPSpace.roomy) {
                                ForEach(vm.completedGroups) { obsidianGroupCard($0, vm: vm) }
                            }
                        }
                    }
                    .padding(.horizontal, VPSpace.roomy)
                    .padding(.top, VPSpace.hero)
                    .padding(.bottom, VPSpace.section)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .refreshable { await vm.load() }
            }
        }
    }

    // MARK: Summary + sections + menu

    private func downloadsSummaryCard(_ vm: DownloadsViewModel) -> some View {
        VPCard(elevation: .raised) {
            VStack(alignment: .leading, spacing: VPSpace.normal) {
                HStack(alignment: .top, spacing: VPSpace.section) {
                    summaryStat("\(vm.activeTaskCount)", "Active", tint: vm.hasActiveTasks ? VPColor.accent : VPColor.textTertiary)
                    summaryStat("\(vm.completedTaskCount)", "Downloaded", tint: VPColor.success)
                    summaryStat(formatBytes(vm.totalDownloadedBytes), "On device", tint: VPColor.info)
                    if vm.hasFailedTasks {
                        summaryStat("\(vm.failedTaskCount)", "Failed", tint: VPColor.danger)
                    }
                    Spacer(minLength: 0)
                }
                if vm.hasActiveTasks {
                    VPProgressBar(
                        value: vm.aggregateActiveProgress,
                        height: 8,
                        label: "\(Int((vm.aggregateActiveProgress * 100).rounded()))% overall",
                        tint: VPColor.accent
                    )
                }
            }
        }
        .accessibilityElement(children: .combine)
    }

    private func summaryStat(_ value: String, _ label: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value).font(VPFont.title2).foregroundStyle(tint)
            Text(label).font(VPFont.caption).foregroundStyle(VPColor.textSecondary)
        }
    }

    private func downloadsSectionHeader(_ title: String, systemImage: String, count: Int) -> some View {
        HStack {
            VPSectionHeader(title: title, systemImage: systemImage)
            VPBadge(text: "\(count)").accessibilityLabel("\(count) \(title)")
        }
    }

    private func downloadsMenu(_ vm: DownloadsViewModel) -> some View {
        Menu {
            Picker("Sort by", selection: Binding(get: { vm.sortOption }, set: { vm.sortOption = $0 })) {
                ForEach(DownloadSortOption.allCases) { option in
                    Label(option.label, systemImage: option.systemImage).tag(option)
                }
            }
            Divider()
            if vm.hasFailedTasks {
                Button { Task { await vm.retryAllFailed() } } label: {
                    Label("Retry All Failed", systemImage: "arrow.clockwise")
                }
            }
            if vm.hasActiveTasks {
                Button(role: .destructive) { Task { await vm.cancelAllActive() } } label: {
                    Label("Cancel All Active", systemImage: "xmark")
                }
            }
            if vm.hasCompletedTasks {
                Button(role: .destructive) { Task { await vm.clearCompleted() } } label: {
                    Label("Clear Completed", systemImage: "trash")
                }
            }
        } label: {
            Image(systemName: "ellipsis")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(VPColor.textSecondary)
                .frame(width: VPSpace.minTapTarget, height: VPSpace.minTapTarget)
                .glassSurface(.rest, cornerRadius: VPSpace.minTapTarget / 2)
                .contentShape(Circle())
        }
        .accessibilityLabel("Downloads options")
    }

    private func obsidianStateSurface(
        icon: String,
        title: String,
        message: String?,
        tint: Color,
        actionTitle: String,
        action: @escaping () -> Void
    ) -> some View {
        VStack {
            Spacer()
            VPStateCard(systemImage: icon, title: title, message: message, tint: tint, actionTitle: actionTitle, action: action)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(VPSpace.roomy)
    }

    private func obsidianInlineErrorBanner(_ error: AppError, vm: DownloadsViewModel) -> some View {
        HStack(spacing: VPSpace.snug) {
            Image(systemName: "wifi.exclamationmark")
                .foregroundStyle(VPColor.warning)
                .accessibilityHidden(true)
            Text(error.errorDescription ?? "Couldn’t refresh downloads.")
                .font(VPFont.bodyEmphasis)
                .foregroundStyle(VPColor.textPrimary)
            Spacer(minLength: VPSpace.snug)
            Button { retryRootLoad(vm) } label: {
                Label("Retry", systemImage: "arrow.clockwise")
            }
            .buttonStyle(VPButtonStyle(kind: .secondary))
        }
        .padding(VPSpace.normal)
        .glassSurface(.rest, cornerRadius: VPRadius.control)
    }

    private func obsidianGroupCard(_ group: DownloadMediaGroup, vm: DownloadsViewModel) -> some View {
        VPCard(elevation: .raised, padding: VPSpace.tight) {
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: VPSpace.normal) {
                    AsyncImage(url: group.posterURL) { phase in
                        switch phase {
                        case .success(let image):
                            image.resizable().aspectRatio(2 / 3, contentMode: .fill)
                        case .empty:
                            posterPlaceholder(for: group).overlay { ProgressView().controlSize(.small) }
                        default:
                            posterPlaceholder(for: group)
                        }
                    }
                    .frame(width: 96, height: 144)
                    .clipShape(RoundedRectangle(cornerRadius: VPRadius.chip, style: .continuous))

                    VStack(alignment: .leading, spacing: VPSpace.tight) {
                        Text(group.mediaTitle.isEmpty ? "Unknown Title" : group.mediaTitle)
                            .font(VPFont.title2)
                            .foregroundStyle(VPColor.textPrimary)
                            .lineLimit(2)
                        HStack(spacing: VPSpace.tight) {
                            VPBadge(
                                text: group.mediaType == "series" ? "Series" : "Movie",
                                tint: group.mediaType == "series" ? VPColor.info : VPColor.accent
                            )
                            Text("\(group.completedCount)/\(group.totalCount) downloaded")
                                .font(VPFont.caption)
                                .foregroundStyle(VPColor.textSecondary)
                        }
                        if group.hasActiveDownloads {
                            VPProgressBar(value: group.overallProgress, height: 8, tint: VPColor.accent)
                                .padding(.top, VPSpace.micro)
                        }
                    }

                    Spacer(minLength: VPSpace.tight)

                    obsidianIconButton("trash", label: "Delete all downloads", tint: VPColor.danger) {
                        confirmDeleteMediaId = group.mediaId
                    }
                    .confirmationDialog(
                        "Delete All Downloads?",
                        isPresented: Binding(
                            get: { confirmDeleteMediaId == group.mediaId },
                            set: { if !$0 { confirmDeleteMediaId = nil } }
                        ),
                        titleVisibility: .visible
                    ) {
                        Button("Delete All", role: .destructive) {
                            Task { await vm.removeAll(mediaId: group.mediaId) }
                        }
                        Button("Cancel", role: .cancel) {}
                    } message: {
                        Text("This will permanently delete all downloaded files for \"\(group.mediaTitle)\" from storage.")
                    }
                }
                .padding(VPSpace.snug)

                Divider().overlay(VPColor.specularDim).padding(.horizontal, VPSpace.snug)

                ForEach(group.tasks, id: \.id) { task in
                    obsidianTaskRow(task, vm: vm, isSeries: group.mediaType == "series")
                    if task.id != group.tasks.last?.id {
                        Divider().overlay(VPColor.specularDim).padding(.leading, VPSpace.snug)
                    }
                }
            }
        }
        .contextMenu {
            Button(role: .destructive) {
                confirmDeleteMediaId = group.mediaId
            } label: {
                Label("Delete \(group.mediaTitle)", systemImage: "trash")
            }
        }
    }

    private func obsidianTaskRow(_ task: DownloadTask, vm: DownloadsViewModel, isSeries: Bool) -> some View {
        HStack(spacing: VPSpace.snug) {
            VStack(alignment: .leading, spacing: VPSpace.micro) {
                Text(isSeries ? task.displayTitle : task.fileName)
                    .font(VPFont.bodyEmphasis)
                    .foregroundStyle(VPColor.textPrimary)
                    .lineLimit(1)
                HStack(spacing: VPSpace.tight) {
                    VPBadge(text: task.status.rawValue.capitalized, tint: statusColor(for: task.status))
                    if task.status == .completed, let bytes = task.totalBytes, bytes > 0 {
                        Text(formatBytes(bytes))
                            .font(VPFont.caption)
                            .foregroundStyle(VPColor.textTertiary)
                    }
                }
                if task.status == .downloading || task.status == .queued || task.status == .resolving {
                    VPProgressBar(value: task.progress, height: 6, label: progressText(for: task), tint: statusColor(for: task.status))
                        .padding(.top, 2)
                }
                if let message = task.errorMessage, !message.isEmpty {
                    Text(message)
                        .font(VPFont.caption)
                        .foregroundStyle(VPColor.danger)
                        .lineLimit(2)
                }
            }

            Spacer(minLength: VPSpace.tight)

            HStack(spacing: VPSpace.tight) {
                if task.status == .completed {
                    obsidianIconButton("play.fill", label: "Play", tint: VPColor.accent) { playDownload(task, vm: vm) }
                }
                if task.status == .downloading || task.status == .queued || task.status == .resolving {
                    obsidianIconButton("xmark", label: "Cancel download", tint: VPColor.textSecondary) { Task { await vm.cancel(task) } }
                }
                if task.status == .failed || task.status == .cancelled {
                    obsidianIconButton("arrow.clockwise", label: "Retry download", tint: VPColor.info) { Task { await vm.retry(task) } }
                }
                obsidianIconButton("trash", label: "Delete download", tint: VPColor.danger) {
                    confirmDeleteTaskID = task.id
                }
                .confirmationDialog(
                    "Delete Download?",
                    isPresented: Binding(
                        get: { confirmDeleteTaskID == task.id },
                        set: { if !$0 { confirmDeleteTaskID = nil } }
                    ),
                    titleVisibility: .visible
                ) {
                    Button("Delete", role: .destructive) {
                        confirmDeleteTaskID = nil
                        Task { await vm.remove(task) }
                    }
                    Button("Cancel", role: .cancel) {}
                } message: {
                    Text("This will permanently delete \"\(task.displayTitle)\" from storage.")
                }
            }
        }
        .padding(.horizontal, VPSpace.snug)
        .padding(.vertical, VPSpace.tight)
        .frame(minHeight: VPSpace.minTapTarget)
    }

    private func obsidianIconButton(
        _ systemName: String,
        label: String,
        tint: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: VPSpace.minTapTarget, height: VPSpace.minTapTarget)
                .glassSurface(.rest, cornerRadius: VPSpace.minTapTarget / 2)
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .vpInteractive()
        .accessibilityLabel(label)
    }

    @ViewBuilder
    private func content(_ vm: DownloadsViewModel) -> some View {
        switch errorSurfaceMode(for: vm) {
        case .rootError:
            if let error = vm.rootError {
                downloadsErrorState(error, vm: vm)
            }
        case .inlineError, .none:
            if vm.groups.isEmpty {
                downloadsEmptyState
            } else {
                VStack(spacing: 12) {
                    if case .inlineError = errorSurfaceMode(for: vm), let error = vm.rootError {
                        downloadsInlineErrorBanner(error, vm: vm)
                            .padding(.horizontal, 24)
                            .padding(.top, 16)
                    }

                    ScrollView {
                        LazyVStack(spacing: 24) {
                            ForEach(vm.groups) { group in
                                mediaGroupCard(group, vm: vm)
                            }
                        }
                        .padding(.horizontal, 24)
                        .padding(.bottom, 16)
                    }
                    .refreshable {
                        await vm.load()
                    }
                }
            }
        }
    }

    private func retryRootLoad(_ vm: DownloadsViewModel) {
        reloadTask?.cancel()
        reloadTask = Task {
            await vm.load()
            await performQADownloadActionIfNeeded(vm)
        }
    }

    private func downloadsInlineErrorBanner(_ error: AppError, vm: DownloadsViewModel) -> some View {
        HStack(alignment: .top, spacing: 12) {
            AppErrorInlineView(error: error)

            Spacer(minLength: 12)

            Button {
                retryRootLoad(vm)
            } label: {
                GlassTag(text: "Retry", tintColor: .white.opacity(0.16), symbol: "arrow.clockwise")
            }
            .buttonStyle(.plain)
        }
        .padding(14)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14))
        .overlay {
            RoundedRectangle(cornerRadius: 14)
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

    private func downloadsErrorState(_ error: AppError, vm: DownloadsViewModel) -> some View {
        ScrollView {
            VStack(spacing: 18) {
                CinematicStateCard(
                    accent: .orange,
                    artworkName: "genre-art-deep",
                    minHeight: 250
                ) {
                    VStack(alignment: .leading, spacing: 16) {
                        HStack(alignment: .top, spacing: 14) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.system(size: 28, weight: .semibold))
                                .foregroundStyle(.white)
                                .frame(width: 52, height: 52)
                                .background(Color.orange.opacity(0.28), in: Circle())
                                .overlay {
                                    Circle()
                                        .strokeBorder(.white.opacity(0.18), lineWidth: 1)
                                }

                            VStack(alignment: .leading, spacing: 6) {
                                GlassTag(text: "Downloads unavailable", tintColor: .orange.opacity(0.24), symbol: "wifi.exclamationmark")
                                Text(error.errorDescription ?? "Downloads couldn’t load right now.")
                                    .font(.title3.weight(.semibold))
                                if let suggestion = error.recoverySuggestion {
                                    Text(suggestion)
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                            }

                            Spacer(minLength: 0)
                        }

                        FlowLayout(spacing: 10) {
                            SpatialButton(title: "Retry", icon: "arrow.clockwise", tint: .orange) {
                                retryRootLoad(vm)
                            }

                            Button {
                                appState.selectedTab = .discover
                            } label: {
                                GlassTag(text: "Browse Discover", tintColor: .white.opacity(0.18), symbol: "sparkles")
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding(.top, 12)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
            .frame(maxWidth: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .refreshable {
            await vm.load()
        }
    }

    private func mediaGroupCard(_ group: DownloadMediaGroup, vm: DownloadsViewModel) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            // Banner header with poster
            HStack(spacing: 16) {
                // Poster thumbnail
                AsyncImage(url: group.posterURL) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(2 / 3, contentMode: .fill)
                    case .failure:
                        posterPlaceholder(for: group)
                    case .empty:
                        posterPlaceholder(for: group)
                            .overlay { ProgressView().controlSize(.small) }
                    @unknown default:
                        posterPlaceholder(for: group)
                    }
                }
                .frame(width: 60, height: 90)
                .clipShape(RoundedRectangle(cornerRadius: 8))

                VStack(alignment: .leading, spacing: 4) {
                    Text(group.mediaTitle.isEmpty ? "Unknown Title" : group.mediaTitle)
                        .font(.headline)
                        .lineLimit(2)

                    HStack(spacing: 8) {
                        GlassTag(
                            text: group.mediaType == "series" ? "Series" : "Movie",
                            tintColor: group.mediaType == "series" ? .blue : .purple
                        )
                        Text("\(group.completedCount)/\(group.totalCount) downloaded")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    if group.hasActiveDownloads {
                        GlassProgressBar(
                            progress: group.overallProgress,
                            tint: .blue
                        )
                    }
                }

                Spacer()

                // Delete all button for this media group
                Button(role: .destructive) {
                    confirmDeleteMediaId = group.mediaId
                } label: {
                    Image(systemName: "trash.circle.fill")
                        .font(.title2)
                        .foregroundStyle(.red)
                }
                .buttonStyle(.plain)
                .help("Delete all downloads for this title")
                .confirmationDialog(
                    "Delete All Downloads?",
                    isPresented: Binding(
                        get: { confirmDeleteMediaId == group.mediaId },
                        set: { if !$0 { confirmDeleteMediaId = nil } }
                    ),
                    titleVisibility: .visible
                ) {
                    Button("Delete All", role: .destructive) {
                        Task { await vm.removeAll(mediaId: group.mediaId) }
                    }
                    Button("Cancel", role: .cancel) {}
                } message: {
                    Text("This will permanently delete all downloaded files for \"\(group.mediaTitle)\" from storage.")
                }
            }
            .padding(16)

            Divider()
                .padding(.horizontal, 16)

            // Individual download rows
            VStack(spacing: 0) {
                ForEach(group.tasks, id: \.id) { task in
                    downloadRow(task, vm: vm, isSeries: group.mediaType == "series")
                    if task.id != group.tasks.last?.id {
                        Divider()
                            .padding(.horizontal, 16)
                    }
                }
            }
        }
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
        .overlay {
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(
                    LinearGradient(
                        colors: [.white.opacity(0.28), .white.opacity(0.06)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        }
        .shadow(color: .black.opacity(0.07), radius: 24, y: 0)
        .shadow(color: .black.opacity(0.13), radius: 8, y: 4)
        #if os(visionOS)
        .hoverEffect(.lift)
        #endif
    }

    private func downloadRow(_ task: DownloadTask, vm: DownloadsViewModel, isSeries: Bool) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(isSeries ? task.displayTitle : task.fileName)
                    .font(.subheadline)
                    .lineLimit(1)

                HStack(spacing: 6) {
                    GlassTag(
                        text: task.status.rawValue.capitalized,
                        tintColor: statusColor(for: task.status),
                        weight: .semibold
                    )
                    if task.status == .downloading || task.status == .queued {
                        Text(progressText(for: task))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    if task.status == .completed, let bytes = task.totalBytes, bytes > 0 {
                        Text(formatBytes(bytes))
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }

                if task.status == .downloading || task.status == .queued || task.status == .resolving {
                    GlassProgressBar(
                        progress: task.progress,
                        tint: statusColor(for: task.status)
                    )
                }

                if let message = task.errorMessage, !message.isEmpty {
                    Text(message)
                        .font(.caption2)
                        .foregroundStyle(.red)
                        .lineLimit(2)
                }
            }

            Spacer(minLength: 8)

            HStack(spacing: 16) {
                if task.status == .completed {
                    Button {
                        playDownload(task, vm: vm)
                    } label: {
                        Image(systemName: "play.circle.fill")
                            .font(.title3)
                            .foregroundStyle(Color.vpRed)
                            .frame(minWidth: 44, minHeight: 44)
                            .contentShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .help("Play")
                    #if os(visionOS)
                    .hoverEffect(.highlight)
                    #endif
                }

                if task.status == .downloading || task.status == .queued || task.status == .resolving {
                    Button {
                        Task { await vm.cancel(task) }
                    } label: {
                        Image(systemName: "xmark.circle")
                            .font(.body)
                            .foregroundStyle(.secondary)
                            .frame(minWidth: 44, minHeight: 44)
                            .contentShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .help("Cancel")
                    #if os(visionOS)
                    .hoverEffect(.highlight)
                    #endif
                }

                if task.status == .failed || task.status == .cancelled {
                    Button {
                        Task { await vm.retry(task) }
                    } label: {
                        Image(systemName: "arrow.clockwise.circle")
                            .font(.body)
                            .foregroundStyle(.blue)
                            .frame(minWidth: 44, minHeight: 44)
                            .contentShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .help("Retry")
                    #if os(visionOS)
                    .hoverEffect(.highlight)
                    #endif
                }

                Button(role: .destructive) {
                    confirmDeleteTaskID = task.id
                } label: {
                    Image(systemName: "trash")
                        .font(.body)
                        .foregroundStyle(.red.opacity(0.7))
                        .frame(minWidth: 44, minHeight: 44)
                        .contentShape(Circle())
                }
                .buttonStyle(.plain)
                .help("Delete")
                #if os(visionOS)
                .hoverEffect(.highlight)
                #endif
                .confirmationDialog(
                    "Delete Download?",
                    isPresented: Binding(
                        get: { confirmDeleteTaskID == task.id },
                        set: { if !$0 { confirmDeleteTaskID = nil } }
                    ),
                    titleVisibility: .visible
                ) {
                    Button("Delete", role: .destructive) {
                        confirmDeleteTaskID = nil
                        Task { await vm.remove(task) }
                    }
                    Button("Cancel", role: .cancel) {}
                } message: {
                    Text("This will permanently delete \"\(task.displayTitle)\" from storage.")
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    private func playDownload(_ task: DownloadTask, vm: DownloadsViewModel) {
        guard task.status == .completed else { return }
        guard let fileURL = task.destinationURL else {
            playbackValidationMessage = "The downloaded file for \"\(task.displayTitle)\" is no longer available on disk."
            Task { await vm.load() }
            return
        }
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            playbackValidationMessage = "The downloaded file for \"\(task.displayTitle)\" is no longer available on disk."
            Task { await vm.load() }
            return
        }

        #if os(macOS)
        vm.playFile(task)
        #else
        guard appState.activePlayerSession == nil else {
            playbackValidationMessage = "A video is already playing. Close it before starting another."
            return
        }
        let stream = StreamInfo(
            streamURL: fileURL,
            quality: .unknown,
            codec: .unknown,
            audio: .unknown,
            source: .unknown,
            hdr: .sdr,
            fileName: task.fileName,
            sizeBytes: task.totalBytes,
            debridService: "local"
        )
        let request = PlayerSessionRequest(
            stream: stream,
            mediaTitle: task.displayTitle,
            mediaId: task.mediaId,
            episodeId: task.episodeId
        )
        appState.activePlayerSession = request
        openWindow(id: "player", value: request)
        #endif
    }

    @MainActor
    private func performQADownloadActionIfNeeded(_ vm: DownloadsViewModel) async {
        guard QARuntimeOptions.isEnabled else { return }
        guard !didPerformQADownloadAction else { return }
        guard let action = QARuntimeOptions.downloadAction else { return }

        switch action {
        case .cancelFirstActive:
            guard let task = vm.tasks.first(where: { !$0.status.isTerminal }) else { return }
            didPerformQADownloadAction = true
            await vm.cancel(task)
        case .retryFirstFailed:
            guard let task = vm.tasks.first(where: { $0.status == .failed || $0.status == .cancelled }) else { return }
            didPerformQADownloadAction = true
            await vm.retry(task)
        case .removeFirst:
            guard let task = vm.tasks.first else { return }
            didPerformQADownloadAction = true
            await vm.remove(task)
        case .removeFirstGroup:
            guard let group = vm.groups.first else { return }
            didPerformQADownloadAction = true
            await vm.removeAll(mediaId: group.mediaId)
        case .playFirstCompleted:
            guard let task = vm.tasks.first(where: { $0.status == .completed }) else { return }
            didPerformQADownloadAction = true
            playDownload(task, vm: vm)
        }
    }

    private func statusColor(for status: DownloadStatus) -> Color {
        switch status {
        case .completed: return .green
        case .failed: return .red
        case .cancelled: return .orange
        case .downloading: return .blue
        case .resolving: return .purple
        case .queued: return .secondary
        }
    }

    private func progressText(for task: DownloadTask) -> String {
        let normalizedProgress = DownloadProgressPolicy.normalizedProgress(
            progress: task.progress,
            bytesWritten: task.bytesWritten,
            totalBytes: task.totalBytes,
            status: task.status
        )
        let pct = Int((normalizedProgress * 100).rounded())

        if let total = task.totalBytes, total > 0 {
            let written = formatBytes(task.bytesWritten)
            let totalText = formatBytes(total)
            return "\(pct)% \u{2022} \(written) / \(totalText)"
        }

        if task.bytesWritten > 0 {
            return "\(pct)% \u{2022} \(formatBytes(task.bytesWritten))"
        }

        return "\(pct)%"
    }

    private static let byteFormatter: ByteCountFormatter = {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useMB, .useGB]
        formatter.countStyle = .file
        return formatter
    }()

    private func formatBytes(_ bytes: Int64) -> String {
        Self.byteFormatter.string(fromByteCount: bytes)
    }

    private var downloadsEmptyState: some View {
        ScrollView {
            VStack(spacing: 18) {
                CinematicStateCard(
                    accent: .blue,
                    artworkName: "genre-art-classics",
                    minHeight: 250
                ) {
                    VStack(alignment: .leading, spacing: 16) {
                        HStack(alignment: .top, spacing: 14) {
                            Image(systemName: "arrow.down.circle.fill")
                                .font(.system(size: 28, weight: .semibold))
                                .foregroundStyle(.white)
                                .frame(width: 52, height: 52)
                                .background(Color.blue.opacity(0.28), in: Circle())
                                .overlay {
                                    Circle()
                                        .strokeBorder(.white.opacity(0.18), lineWidth: 1)
                                }

                            VStack(alignment: .leading, spacing: 6) {
                                GlassTag(text: "Ready when you are", tintColor: .blue.opacity(0.22), symbol: "sparkles")
                                Text("Build your offline shelf")
                                    .font(.title2.weight(.semibold))
                                Text("Downloaded movies and episodes show up here with progress, retry controls, and one-tap playback. Grab a title from Discover, then download the stream you want to keep.")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }

                            Spacer(minLength: 0)
                        }

                        FlowLayout(spacing: 10) {
                            SpatialButton(title: "Browse Discover", icon: "sparkles", tint: .vpRed) {
                                appState.selectedTab = .discover
                            }

                            Button {
                                appState.selectedTab = .search
                            } label: {
                                GlassTag(text: "Search / AI picks", tintColor: .white.opacity(0.18), symbol: "magnifyingglass")
                            }
                            .buttonStyle(.plain)

                            Button {
                                appState.selectedTab = .library
                            } label: {
                                GlassTag(text: "Check Library", tintColor: .white.opacity(0.18), symbol: "books.vertical")
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding(.top, 12)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
            .frame(maxWidth: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    private func posterPlaceholder(for group: DownloadMediaGroup) -> some View {
        ArtworkFallbackPosterView(
            title: group.mediaTitle.isEmpty ? "Download" : group.mediaTitle,
            type: group.mediaType == "series" ? .series : .movie,
            compact: true
        )
    }
}
