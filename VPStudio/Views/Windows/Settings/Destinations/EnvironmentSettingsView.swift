import SwiftUI
import UniformTypeIdentifiers

// MARK: - Environment Settings

enum EnvironmentSettingsLayoutPolicy {
    static let contentMaxWidth: CGFloat = 1120
    static let bottomContentPadding: CGFloat = 96
    static let bottomViewportInset: CGFloat = 64
    static let minimumRowHeight: CGFloat = 64
    static let sectionSpacing: CGFloat = 10
    static let rowInsets = EdgeInsets(top: 6, leading: 22, bottom: 6, trailing: 22)
    static let importedActionSpacing: CGFloat = 16
    static let rowIconWidth: CGFloat = 32
    static let standardActionColumnMinWidth: CGFloat = 148
    static let importedActionColumnMinWidth: CGFloat = 184
    static let primaryActionMinWidth: CGFloat = 108
    static let deleteActionButtonSize: CGFloat = VPSpace.minTapTarget
}

enum EnvironmentSettingsCopyPolicy {
    static let autoOpenHelp = "When enabled, the selected immersive environment opens automatically when video starts. Apple Environment stays in the system window."
    static let genreSuggestionHelp = "When enabled, playback chooses an installed environment whose saved tag matches the media genre. If nothing matches, playback stays in Apple Environment."
}

enum EnvironmentErrorPresentationPolicy {
    static func displayMessage(for error: Error) -> String {
        IndexerLogSanitizer.redactedErrorMessage(error)
    }

    static func deleteFailureMessage(for error: Error) -> String {
        "Failed to delete: \(displayMessage(for: error))"
    }
}

enum EnvironmentSettingsErrorPresentationPolicy {
    static func displayMessage(for error: Error) -> String {
        EnvironmentErrorPresentationPolicy.displayMessage(for: error)
    }
}

struct EnvironmentSettingsView: View {
    @Environment(AppState.self) private var appState
    #if os(visionOS)
    @Environment(\.dismissImmersiveSpace) private var dismissImmersiveSpace
    #endif
    @State private var assets: [EnvironmentAsset] = []
    @State private var isImporting = false
    @State private var isImportingEnvironment = false
    @State private var environmentError: String?
    @State private var deletingAssetIDs: Set<String> = []
    @State private var autoOpenEnvironment = true
    @State private var autoSuggestEnvironmentByGenre = true
    @State private var assetLoadTask: Task<Void, Never>?
    @State private var pendingDeletion: PendingDeletion?
    private let disablesAutomaticTasks: Bool

    private struct PendingDeletion: Identifiable {
        let id: String
        let name: String
    }

    init(
        initialAssets: [EnvironmentAsset] = [],
        initialAutoOpenEnvironment: Bool = true,
        initialAutoSuggestEnvironmentByGenre: Bool = true,
        disablesAutomaticTasks: Bool = false
    ) {
        _assets = State(initialValue: initialAssets)
        _autoOpenEnvironment = State(initialValue: initialAutoOpenEnvironment)
        _autoSuggestEnvironmentByGenre = State(initialValue: initialAutoSuggestEnvironmentByGenre)
        self.disablesAutomaticTasks = disablesAutomaticTasks
    }

    var body: some View {
        List {
            Section("Curated Environments") {
                standardRoomRow
                builtInCinemaRow

                let bundled = assets.filter { $0.sourceType == .bundled }
                if bundled.isEmpty {
                    Text("Import \(EnvironmentImportValidationPolicy.supportedExtensionDisplayList) files to add custom environments.")
                        .foregroundStyle(VPColor.textSecondary)
                } else {
                    ForEach(bundled) { asset in
                        environmentRow(asset)
                    }
                }
            }
            .listRowBackground(VPEnvironmentListRowBackground())
            .listRowSeparator(.hidden)
            .listRowInsets(EnvironmentSettingsLayoutPolicy.rowInsets)

            Section("Playback") {
                playbackControlsRow
            }
            .listRowBackground(VPEnvironmentListRowBackground())
            .listRowSeparator(.hidden)
            .listRowInsets(EnvironmentSettingsLayoutPolicy.rowInsets)

            Section("Imported Environments") {
                importEnvironmentRow

                ForEach(assets.filter { $0.sourceType == .imported }) { asset in
                    environmentRow(asset)
                }
            }
            .listRowBackground(VPEnvironmentListRowBackground())
            .listRowSeparator(.hidden)
            .listRowInsets(EnvironmentSettingsLayoutPolicy.rowInsets)
        }
        .listStyle(.plain)
        .environmentSettingsListSectionSpacing()
        .scrollContentBackground(.hidden)
        .environment(\.defaultMinListRowHeight, EnvironmentSettingsLayoutPolicy.minimumRowHeight)
        .contentMargins(.bottom, EnvironmentSettingsLayoutPolicy.bottomContentPadding, for: .scrollContent)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            Color.clear
                .frame(height: EnvironmentSettingsLayoutPolicy.bottomViewportInset)
                .accessibilityHidden(true)
        }
        .frame(maxWidth: EnvironmentSettingsLayoutPolicy.contentMaxWidth)
        .frame(maxWidth: .infinity, alignment: .center)
        .background {
            VPEnvironmentBackdrop()
        }
        .navigationTitle("Environments")
        .task {
            guard !disablesAutomaticTasks else { return }
            await coalescedLoadAssets()
            autoOpenEnvironment = (try? await appState.settingsManager.getBool(
                key: SettingsKeys.autoOpenEnvironment, default: true
            )) ?? true
            autoSuggestEnvironmentByGenre = (try? await appState.settingsManager.getBool(
                key: SettingsKeys.autoSuggestEnvironmentByGenre, default: true
            )) ?? true
        }
        .refreshable {
            guard !disablesAutomaticTasks else { return }
            await coalescedLoadAssets()
        }
        .onChange(of: autoOpenEnvironment) { _, newValue in
            guard !disablesAutomaticTasks else { return }
            saveAutoOpenEnvironment(newValue)
        }
        .onChange(of: autoSuggestEnvironmentByGenre) { _, newValue in
            guard !disablesAutomaticTasks else { return }
            saveAutoSuggestEnvironmentByGenre(newValue)
        }
        .onReceive(NotificationCenter.default.publisher(for: .environmentsDidChange)) { _ in
            guard !disablesAutomaticTasks else { return }
            scheduleAssetLoad()
        }
        .onDisappear {
            assetLoadTask?.cancel()
            assetLoadTask = nil
        }
        .fileImporter(
            isPresented: $isImporting,
            allowedContentTypes: supportedEnvironmentTypes,
            allowsMultipleSelection: false
        ) { result in
            Task { await handleFileImport(result) }
        }
        .alert(
            "Environment Error",
            isPresented: Binding(
                get: { environmentError != nil },
                set: { isPresented in
                    if !isPresented { environmentError = nil }
                }
            )
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(environmentError ?? "Unknown error")
        }
        .confirmationDialog(
            "Delete Imported Environment?",
            isPresented: Binding(
                get: { pendingDeletion != nil },
                set: { if !$0 { pendingDeletion = nil } }
            ),
            titleVisibility: .visible,
            presenting: pendingDeletion
        ) { deletion in
            Button("Delete", role: .destructive) {
                pendingDeletion = nil
                Task { await deleteImportedEnvironment(id: deletion.id) }
            }
            Button("Cancel", role: .cancel) {}
        } message: { deletion in
            Text("Delete \(deletion.name)? This removes the imported environment from disk.")
        }
    }

    @ViewBuilder
    private var standardRoomRow: some View {
        HStack(spacing: 12) {
            Image(systemName: EnvironmentPreviewFallbackArtworkKind.standardRoom.iconName)
                .font(.title2)
                .foregroundStyle(VPColor.textSecondary)
                .frame(width: EnvironmentSettingsLayoutPolicy.rowIconWidth)

            VStack(alignment: .leading, spacing: 4) {
                Text(EnvironmentPreviewRowPolicy.appleEnvironmentTitle)
                    .font(.title3.weight(.semibold))
                Text(EnvironmentPreviewRowPolicy.appleEnvironmentTypeLabel)
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(VPColor.textSecondary)
                environmentMetadataText(EnvironmentPreviewRowPolicy.appleEnvironmentDetailText)
                EnvironmentSettingsValueBadge(
                    title: EnvironmentPreviewRowPolicy.appleEnvironmentBenefitLabel,
                    systemImage: "sparkles.tv"
                )
            }

            Spacer()

            let status = standardRoomStatus
            if status.isHighlighted {
                EnvironmentSettingsStatusLabel(status: status)
            } else {
                Button("Activate") {
                    Task { await clearActiveEnvironment() }
                }
                .buttonStyle(.bordered)
                .controlSize(.regular)
                .frame(minWidth: EnvironmentSettingsLayoutPolicy.primaryActionMinWidth, alignment: .trailing)
            }
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private var builtInCinemaRow: some View {
        HStack(spacing: 12) {
            Image(systemName: "theatermasks")
                .font(.title2)
                .foregroundStyle(VPColor.textSecondary)
                .frame(width: EnvironmentSettingsLayoutPolicy.rowIconWidth)

            VStack(alignment: .leading, spacing: 4) {
                Text("Cinema Environment")
                    .font(.title3.weight(.semibold))
                Text("Built-in")
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(VPColor.textSecondary)
                environmentMetadataText("Available from the player during AVPlayer playback.")
            }

            Spacer()

            let status = cinemaEnvironmentStatus
            if status.isHighlighted {
                EnvironmentSettingsStatusLabel(status: status)
            } else {
                EnvironmentSettingsPassiveActionLabel(
                    title: "Player only",
                    systemImage: "play.rectangle"
                )
            }
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private func environmentRow(_ asset: EnvironmentAsset) -> some View {
        let status = environmentStatus(for: asset)
        let isDeleting = isDeletingAsset(asset)

        HStack(alignment: .center, spacing: 12) {
            Image(systemName: asset.sourceType == .bundled ? "sparkles" : "square.and.arrow.down")
                .font(.title2)
                .foregroundStyle(VPColor.textSecondary)
                .frame(width: EnvironmentSettingsLayoutPolicy.rowIconWidth)

            VStack(alignment: .leading, spacing: 4) {
                Text(asset.name)
                    .font(.title3.weight(.semibold))
                    .lineLimit(1)
                    .truncationMode(.tail)
                Text(asset.sourceType == .bundled ? "Built-in" : "Imported")
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(VPColor.textSecondary)
                if asset.sourceType == .imported {
                    importedEnvironmentDetailLine(for: asset)
                } else if let metadata = bundledEnvironmentMetadataText(for: asset) {
                    environmentMetadataText(metadata)
                    if let sourceURL = EnvironmentURLPolicy.webURL(from: asset.sourceAttributionURL) {
                        environmentSourceLink(sourceURL)
                    }
                }
            }
            .layoutPriority(1)

            Spacer(minLength: 12)

            VStack(alignment: .trailing, spacing: 8) {
                if isDeleting {
                    Label("Deleting", systemImage: "hourglass")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(VPColor.textSecondary)

                        ProgressView()
                            .controlSize(.small)
                } else if status.isHighlighted {
                    EnvironmentSettingsStatusLabel(status: status)

                    if shouldShowEnvironmentExitAction(for: status) || asset.sourceType == .imported {
                        HStack(spacing: EnvironmentSettingsLayoutPolicy.importedActionSpacing) {
                            if shouldShowEnvironmentExitAction(for: status) {
                                Button {
                                    Task { await clearActiveEnvironment() }
                                } label: {
                                    HStack(spacing: 6) {
                                        Image(systemName: "xmark.circle")
                                        Text(environmentExitActionTitle(for: status))
                                    }
                                    .lineLimit(1)
                                    .fixedSize(horizontal: true, vertical: false)
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.regular)
                                .frame(minWidth: EnvironmentSettingsLayoutPolicy.primaryActionMinWidth, alignment: .trailing)
                            }

                            if asset.sourceType == .imported {
                                deleteEnvironmentButton(for: asset, isDeleting: isDeleting)
                            }
                        }
                    }
                } else {
                    HStack(spacing: EnvironmentSettingsLayoutPolicy.importedActionSpacing) {
                        Button("Activate") {
                            Task {
                                guard await ensureEnvironmentAssetExists(asset) else {
                                    environmentError = PlayerImmersiveTransitionPolicy.missingAssetMessage(assetName: asset.name)
                                    await coalescedLoadAssets()
                                    return
                                }
                                guard await appState.activateEnvironmentAsset(asset) else {
                                    environmentError = PlayerImmersiveTransitionPolicy.missingAssetMessage(assetName: asset.name)
                                    await coalescedLoadAssets()
                                    return
                                }
                                await coalescedLoadAssets()
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.regular)
                        .frame(minWidth: EnvironmentSettingsLayoutPolicy.primaryActionMinWidth, alignment: .trailing)
                        .disabled(isDeleting)

                        if asset.sourceType == .imported {
                            deleteEnvironmentButton(for: asset, isDeleting: isDeleting)
                        }
                    }
                }
            }
            .frame(
                minWidth: asset.sourceType == .imported
                    ? EnvironmentSettingsLayoutPolicy.importedActionColumnMinWidth
                    : EnvironmentSettingsLayoutPolicy.standardActionColumnMinWidth,
                alignment: .trailing
            )
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private var importEnvironmentRow: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 12) {
                importEnvironmentButton

                if assets.filter({ $0.sourceType == .imported }).isEmpty {
                    Text("No imported environments yet.")
                        .font(.callout)
                        .foregroundStyle(VPColor.textSecondary)
                        .lineLimit(1)
                }

                Spacer(minLength: 0)
            }

            VStack(alignment: .leading, spacing: 8) {
                importEnvironmentButton

                if assets.filter({ $0.sourceType == .imported }).isEmpty {
                    Text("No imported environments yet.")
                        .font(.callout)
                        .foregroundStyle(VPColor.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var importEnvironmentButton: some View {
        Button {
            isImporting = true
        } label: {
            if isImportingEnvironment {
                HStack(spacing: 8) {
                    ProgressView()
                        .controlSize(.small)
                    Text("Importing")
                }
            } else {
                Label("Import Environment", systemImage: "square.and.arrow.down")
            }
        }
        .disabled(isImportingEnvironment)
        .help("Supports \(EnvironmentImportValidationPolicy.supportedExtensionDisplayList). HDR/EXR load as skyboxes; USDZ/Reality load as scenes.")
    }

    private var standardRoomStatus: EnvironmentPreviewCardStatus {
        EnvironmentPreviewRowPolicy.standardRoomStatus(
            selectedAssetID: effectiveSelectedAssetID,
            activeEnvironment: appState.activeEnvironment,
            isImmersiveSpaceOpen: appState.isImmersiveSpaceOpen
        )
    }

    private var cinemaEnvironmentStatus: EnvironmentPreviewCardStatus {
        EnvironmentPreviewRowPolicy.cinemaStatus(
            activeEnvironment: appState.activeEnvironment,
            isImmersiveSpaceOpen: appState.isImmersiveSpaceOpen
        )
    }

    private func environmentStatus(for asset: EnvironmentAsset) -> EnvironmentPreviewCardStatus {
        EnvironmentPreviewRowPolicy.assetStatus(
            assetID: asset.id,
            selectedAssetID: effectiveSelectedAssetID,
            activeEnvironment: appState.activeEnvironment,
            isImmersiveSpaceOpen: appState.isImmersiveSpaceOpen
        )
    }

    private var effectiveSelectedAssetID: String? {
        EnvironmentPreviewRowPolicy.effectiveSelectedAssetID(
            appStateSelectedID: appState.selectedEnvironmentAsset?.id,
            assets: assets
        )
    }

    private func ensureEnvironmentAssetExists(_ asset: EnvironmentAsset) async -> Bool {
        if await appState.environmentCatalogManager.resolvedAssetURL(for: asset) != nil {
            return true
        }

        if asset.sourceType == .imported {
            try? await appState.environmentCatalogManager.deleteAsset(id: asset.id)
            await appState.clearEnvironmentSelectionIfCurrent(assetID: asset.id)
        }
        return false
    }

    private func shouldShowEnvironmentExitAction(for status: EnvironmentPreviewCardStatus) -> Bool {
        status == .active
    }

    private func environmentExitActionTitle(for status: EnvironmentPreviewCardStatus) -> String {
        status == .active ? "Exit" : ""
    }

    private func bundledEnvironmentMetadataText(for asset: EnvironmentAsset) -> String? {
        guard asset.sourceType == .bundled,
              let licenseName = asset.licenseName?.trimmingCharacters(in: .whitespacesAndNewlines),
              !licenseName.isEmpty,
              licenseName.localizedCaseInsensitiveCompare("Built-in") != .orderedSame
        else {
            return nil
        }
        return licenseName
    }

    private func environmentMetadataText(_ value: String) -> some View {
        Text(value)
            .font(.subheadline)
            .foregroundStyle(VPColor.textSecondary)
            .lineSpacing(1)
    }

    @ViewBuilder
    private func importedEnvironmentDetailLine(for asset: EnvironmentAsset) -> some View {
        let detail = EnvironmentPreviewRowPolicy.assetDetailLabel(for: asset)
        if let sourceURL = EnvironmentURLPolicy.webURL(from: asset.sourceAttributionURL) {
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 10) {
                    environmentMetadataText(detail)
                        .lineLimit(1)
                        .truncationMode(.middle)
                    environmentSourceLink(sourceURL)
                }

                VStack(alignment: .leading, spacing: 2) {
                    environmentMetadataText(detail)
                        .lineLimit(1)
                        .truncationMode(.middle)
                    environmentSourceLink(sourceURL)
                }
            }
        } else {
            environmentMetadataText(detail)
                .lineLimit(1)
                .truncationMode(.middle)
        }
    }

    private func deleteEnvironmentButton(for asset: EnvironmentAsset, isDeleting: Bool) -> some View {
        Menu {
            Button(role: .destructive) {
                pendingDeletion = PendingDeletion(id: asset.id, name: asset.name)
            } label: {
                Label("Delete", systemImage: "trash")
            }
        } label: {
            Image(systemName: "ellipsis")
                .font(.body.weight(.semibold))
                .foregroundStyle(VPColor.textPrimary)
                .frame(
                    width: EnvironmentSettingsLayoutPolicy.deleteActionButtonSize,
                    height: EnvironmentSettingsLayoutPolicy.deleteActionButtonSize
                )
                .background(.ultraThinMaterial, in: Circle())
                .overlay {
                    Circle()
                        .strokeBorder(Color.white.opacity(0.18), lineWidth: 0.75)
                }
        }
        .buttonStyle(.plain)
        .controlSize(.regular)
        .help("More actions for \(asset.name).")
        .accessibilityLabel("More actions for \(asset.name)")
        .accessibilityHint("Includes deleting this imported environment after confirmation.")
        .disabled(isDeleting)
    }

    private func environmentSourceLink(_ sourceURL: URL) -> some View {
        Link(destination: sourceURL) {
            Label("Source", systemImage: "arrow.up.right")
                .font(.caption.weight(.medium))
        }
        .foregroundStyle(VPColor.info)
    }

    private var playbackControlsRow: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .top, spacing: 20) {
                playbackToggleBlock(
                    "Auto-open environment on playback",
                    help: EnvironmentSettingsCopyPolicy.autoOpenHelp,
                    isOn: $autoOpenEnvironment
                )
                playbackToggleBlock(
                    "Suggest environment by genre",
                    help: EnvironmentSettingsCopyPolicy.genreSuggestionHelp,
                    isOn: $autoSuggestEnvironmentByGenre
                )
            }

            VStack(alignment: .leading, spacing: 8) {
                playbackToggleBlock(
                    "Auto-open environment on playback",
                    help: EnvironmentSettingsCopyPolicy.autoOpenHelp,
                    isOn: $autoOpenEnvironment
                )
                playbackToggleBlock(
                    "Suggest environment by genre",
                    help: EnvironmentSettingsCopyPolicy.genreSuggestionHelp,
                    isOn: $autoSuggestEnvironmentByGenre
                )
            }
        }
        .padding(.vertical, 2)
    }

    private func playbackToggleBlock(_ title: String, help: String, isOn: Binding<Bool>) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Toggle(title, isOn: isOn)
                .font(.body.weight(.semibold))
            Text(help)
                .font(.subheadline)
                .foregroundStyle(VPColor.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func isDeletingAsset(_ asset: EnvironmentAsset) -> Bool {
        deletingAssetIDs.contains(normalizedAssetID(asset.id))
    }

    private func normalizedAssetID(_ id: String) -> String {
        id.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var supportedEnvironmentTypes: [UTType] {
        let types = EnvironmentImportValidationPolicy.supportedExtensionOrder
            .compactMap { UTType(filenameExtension: $0) }
        return types.isEmpty ? [.data] : types
    }

    @MainActor
    private func handleFileImport(_ result: Result<[URL], Error>) async {
        guard !isImportingEnvironment else { return }
        environmentError = nil

        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            isImportingEnvironment = true
            defer { isImportingEnvironment = false }

            let hasSecurityScope = url.startAccessingSecurityScopedResource()
            defer {
                if hasSecurityScope {
                    url.stopAccessingSecurityScopedResource()
                }
            }

            do {
                _ = try await appState.environmentCatalogManager.importEnvironment(from: url)
                await coalescedLoadAssets()
            } catch {
                environmentError = EnvironmentSettingsErrorPresentationPolicy.displayMessage(for: error)
            }

        case .failure(let error):
            environmentError = EnvironmentSettingsErrorPresentationPolicy.displayMessage(for: error)
        }
    }

    @MainActor
    private func activateEnvironmentAsset(_ asset: EnvironmentAsset) async {
        guard await ensureEnvironmentAssetExists(asset) else {
            environmentError = PlayerImmersiveTransitionPolicy.missingAssetMessage(assetName: asset.name)
            await coalescedLoadAssets()
            return
        }
        guard await appState.activateEnvironmentAsset(asset) else {
            environmentError = PlayerImmersiveTransitionPolicy.missingAssetMessage(assetName: asset.name)
            await coalescedLoadAssets()
            return
        }
        await coalescedLoadAssets()
    }

    @discardableResult
    @MainActor
    private func clearActiveEnvironment() async -> Bool {
        #if os(visionOS)
        if appState.isImmersiveSpaceOpen {
            guard appState.beginImmersiveTransition() else { return false }
            appState.stageImmersiveDismiss(reason: .userInitiated)
            await dismissImmersiveSpace()
            appState.completeImmersiveDismissIfStillPending()
        }
        #endif

        await appState.clearEnvironmentSelection()
        await coalescedLoadAssets()
        return true
    }

    @MainActor
    private func deleteImportedEnvironment(id: String) async {
        let normalizedID = normalizedAssetID(id)
        guard !normalizedID.isEmpty,
              !deletingAssetIDs.contains(normalizedID) else {
            return
        }

        environmentError = nil
        deletingAssetIDs.insert(normalizedID)
        defer { deletingAssetIDs.remove(normalizedID) }

        do {
            let isActiveSelection = EnvironmentPreviewRowPolicy.shouldClearActiveSelection(
                deleting: normalizedID,
                selectedAssetID: appState.selectedEnvironmentAsset?.id,
                assets: assets
            )
            if isActiveSelection {
                guard await clearActiveEnvironment() else {
                    environmentError = "Finish the current environment transition before deleting this environment."
                    return
                }
            }
            try await appState.environmentCatalogManager.deleteAsset(id: normalizedID)
            await coalescedLoadAssets()
        } catch {
            environmentError = EnvironmentSettingsErrorPresentationPolicy.displayMessage(for: error)
        }
    }

    @MainActor
    private func scheduleAssetLoad() {
        assetLoadTask?.cancel()
        assetLoadTask = Task { await loadAssets() }
    }

    @MainActor
    private func coalescedLoadAssets() async {
        scheduleAssetLoad()
        await assetLoadTask?.value
    }

    @MainActor
    private func loadAssets() async {
        do {
            let latestAssets = try await appState.environmentCatalogManager.fetchAssets()
            guard !Task.isCancelled else { return }
            assets = latestAssets
            appState.reconcileEnvironmentSelection(withLoadedAssets: latestAssets)
            environmentError = nil
        } catch {
            guard !Task.isCancelled else { return }
            environmentError = EnvironmentSettingsErrorPresentationPolicy.displayMessage(for: error)
        }
    }

    private func saveAutoOpenEnvironment(_ value: Bool) {
        Task {
            do {
                try await appState.settingsManager.setBool(key: SettingsKeys.autoOpenEnvironment, value: value)
                await MainActor.run {
                    environmentError = nil
                }
            } catch {
                await MainActor.run {
                    environmentError = EnvironmentSettingsErrorPresentationPolicy.displayMessage(for: error)
                }
            }
        }
    }

    private func saveAutoSuggestEnvironmentByGenre(_ value: Bool) {
        Task {
            do {
                try await appState.settingsManager.setBool(key: SettingsKeys.autoSuggestEnvironmentByGenre, value: value)
                await MainActor.run {
                    environmentError = nil
                }
            } catch {
                await MainActor.run {
                    environmentError = EnvironmentSettingsErrorPresentationPolicy.displayMessage(for: error)
                }
            }
        }
    }
}

private extension View {
    @ViewBuilder
    func environmentSettingsListSectionSpacing() -> some View {
        #if os(macOS)
        self
        #else
        self.listSectionSpacing(EnvironmentSettingsLayoutPolicy.sectionSpacing)
        #endif
    }
}

private struct EnvironmentSettingsStatusLabel: View {
    let status: EnvironmentPreviewCardStatus

    var body: some View {
        if let chip = status.chip {
            HStack(spacing: 4) {
                Image(systemName: chip.systemImage)
                Text(chip.title)
            }
                .font(.footnote.weight(.semibold))
                .foregroundStyle(chip.tint)
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)
                .accessibilityLabel("\(chip.title) environment status")
        }
    }
}

private struct EnvironmentSettingsPassiveActionLabel: View {
    let title: String
    let systemImage: String

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: systemImage)
            Text(title)
        }
            .font(.footnote.weight(.semibold))
            .foregroundStyle(VPColor.textSecondary)
            .lineLimit(1)
            .fixedSize(horizontal: true, vertical: false)
            .frame(minWidth: 126, alignment: .trailing)
            .accessibilityLabel("\(title) status")
    }
}

private struct EnvironmentSettingsValueBadge: View {
    let title: String
    let systemImage: String

    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: systemImage)
            Text(title)
        }
            .font(.footnote.weight(.semibold))
            .foregroundStyle(VPColor.info)
            .lineLimit(1)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background {
                Capsule()
                    .fill(VPColor.info.opacity(0.16))
            }
            .overlay {
                Capsule()
                    .strokeBorder(VPColor.info.opacity(0.34), lineWidth: 0.75)
            }
    }
}
