import SwiftUI
import UniformTypeIdentifiers

// MARK: - Environment Settings

struct EnvironmentSettingsView: View {
    @Environment(AppState.self) private var appState
    #if os(visionOS)
    @Environment(\.dismissImmersiveSpace) private var dismissImmersiveSpace
    #endif
    @State private var assets: [EnvironmentAsset] = []
    @State private var isImporting = false
    @State private var isImportingEnvironment = false
    @State private var environmentError: String?
    @State private var installingPresetIDs: Set<String> = []
    @State private var deletingAssetIDs: Set<String> = []
    @State private var autoOpenEnvironment = true
    @State private var autoSuggestEnvironmentByGenre = true
    @State private var assetLoadTask: Task<Void, Never>?
    @State private var pendingDeletion: PendingDeletion?
    private let disablesAutomaticTasks: Bool

    private let onlinePresets = EnvironmentCatalogManager.onlinePresets

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
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(bundled) { asset in
                        environmentRow(asset)
                    }
                }
            }

            Section("Online Presets (Poly Haven HDRI)") {
                ForEach(onlinePresets) { preset in
                    onlinePresetRow(preset)
                }

                Text("Use one-click import for curated sources, then activate from Imported Environments.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Imported Environments") {
                if assets.filter({ $0.sourceType == .imported }).isEmpty {
                    Text("No imported environments yet.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(assets.filter { $0.sourceType == .imported }) { asset in
                        environmentRow(asset)
                    }
                }

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

                Text("Supports \(EnvironmentImportValidationPolicy.supportedExtensionDisplayList). HDR/EXR provide high-dynamic-range skyboxes, PNG/JPG/JPEG import as standard panoramas, and USDZ/Reality files import as scenes.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Playback") {
                Toggle("Auto-open environment on playback", isOn: $autoOpenEnvironment)
                Text("When enabled, the selected environment opens automatically when you start a video.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Toggle("Suggest environment by genre", isOn: $autoSuggestEnvironmentByGenre)
                Text("When enabled, playback switches to an installed environment tagged for the title's genre or mood (when one exists).")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section {
                Text("Selected environments open when immersive playback starts; Active means the room is currently open.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .scrollContentBackground(.hidden)
        .background {
            VPMenuBackground()
                .ignoresSafeArea()
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
            Image(systemName: "rectangle.dashed")
                .font(.title3)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text("Standard Room")
                    .font(.headline)
                Text("No immersive environment")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                environmentMetadataText("Use the default windowed playback space.")
            }

            Spacer()

            let status = standardRoomStatus
            if status.isHighlighted {
                EnvironmentSettingsStatusLabel(status: status)
            } else {
                Button("Use") {
                    Task { await clearActiveEnvironment() }
                }
                .buttonStyle(.bordered)
            }
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private var builtInCinemaRow: some View {
        HStack(spacing: 12) {
            Image(systemName: "theatermasks")
                .font(.title3)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text("Cinema Environment")
                    .font(.headline)
                Text("Built-In")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                environmentMetadataText("Available from the player and Environments tab.")
            }

            Spacer()

            let status = cinemaEnvironmentStatus
            if status.isHighlighted {
                EnvironmentSettingsStatusLabel(status: status)
            }
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private func onlinePresetRow(_ preset: CuratedEnvironmentPreset) -> some View {
        let isInstalled = isPresetInstalled(preset)
        let isInstalling = installingPresetIDs.contains(preset.id)

        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: EnvironmentPreviewRowPolicy.providerIconName(for: preset.provider))
                    .font(.title3)
                    .frame(width: 24)

                VStack(alignment: .leading, spacing: 3) {
                    Text(preset.name)
                        .font(.headline)
                    Text(preset.description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    environmentMetadataText("\(preset.provider.displayName) • \(preset.licenseName)")

                    if let sourceURL = EnvironmentURLPolicy.webURL(from: preset.sourceAttributionURL) {
                        environmentSourceLink(sourceURL)
                    }
                }

                Spacer()

                if isInstalled {
                    Label("Installed", systemImage: "checkmark.circle.fill")
                        .font(.caption)
                        .foregroundStyle(VPColor.success)
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
                    .buttonStyle(.borderedProminent)
                    .frame(minWidth: 92)
                    .disabled(isInstalling)
                }
            }
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private func environmentRow(_ asset: EnvironmentAsset) -> some View {
        let status = environmentStatus(for: asset)
        let isDeleting = isDeletingAsset(asset)

        HStack(alignment: .top, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: asset.sourceType == .bundled ? "sparkles" : "square.and.arrow.down")
                    .font(.title3)
                    .frame(width: 24)

                VStack(alignment: .leading, spacing: 2) {
                    Text(asset.name)
                        .font(.headline)
                    Text(asset.sourceType == .bundled ? "Built-In" : "Imported")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    if asset.sourceType == .imported {
                        environmentMetadataText(EnvironmentPreviewRowPolicy.assetDetailLabel(for: asset))
                            .lineLimit(1)
                    } else if let license = asset.licenseName, !license.isEmpty {
                        environmentMetadataText(license)
                    }

                    if let sourceURL = EnvironmentURLPolicy.webURL(from: asset.sourceAttributionURL) {
                        environmentSourceLink(sourceURL)
                    }
                }

                Spacer(minLength: 12)
            }
            .layoutPriority(1)

            VStack(alignment: .trailing, spacing: 8) {
                if isDeleting {
                    Label("Deleting", systemImage: "hourglass")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    ProgressView()
                        .controlSize(.small)
                } else if status.isHighlighted {
                    EnvironmentSettingsStatusLabel(status: status)

                    Button(environmentActionTitle(for: status)) {
                        Task { await clearActiveEnvironment() }
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                } else {
                    Button("Activate") {
                        Task {
                            guard await ensureImportedEnvironmentAssetExists(asset) else {
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
                    .controlSize(.small)
                    .disabled(isDeleting)
                }

                if asset.sourceType == .imported {
                    Button(role: .destructive) {
                        pendingDeletion = PendingDeletion(id: asset.id, name: asset.name)
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .disabled(isDeleting)
                }
            }
        }
        .padding(.vertical, 6)
    }

    private var standardRoomStatus: EnvironmentPreviewCardStatus {
        EnvironmentPreviewRowPolicy.standardRoomStatus(
            selectedAssetID: effectiveSelectedAssetID,
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

    private func ensureImportedEnvironmentAssetExists(_ asset: EnvironmentAsset) async -> Bool {
        guard asset.sourceType == .imported else { return true }
        if await appState.environmentCatalogManager.resolvedAssetURL(for: asset) != nil {
            return true
        }

        try? await appState.environmentCatalogManager.deleteAsset(id: asset.id)
        await appState.clearEnvironmentSelectionIfCurrent(assetID: asset.id)
        return false
    }

    private func environmentActionTitle(for status: EnvironmentPreviewCardStatus) -> String {
        status == .active ? "Exit" : "Clear"
    }

    private func environmentMetadataText(_ value: String) -> some View {
        Text(value)
            .font(.caption)
            .foregroundStyle(VPColor.textSecondary)
    }

    private func environmentSourceLink(_ sourceURL: URL) -> some View {
        Link(destination: sourceURL) {
            Label("Source", systemImage: "arrow.up.right")
                .font(.caption.weight(.medium))
        }
        .foregroundStyle(VPColor.info)
    }

    private func isDeletingAsset(_ asset: EnvironmentAsset) -> Bool {
        deletingAssetIDs.contains(normalizedAssetID(asset.id))
    }

    private func normalizedAssetID(_ id: String) -> String {
        id.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func isPresetInstalled(_ preset: CuratedEnvironmentPreset) -> Bool {
        assets.contains { asset in
            asset.sourceType == .imported
                && asset.name == preset.name
                && asset.sourceAttributionURL == preset.sourceAttributionURL
        }
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
                environmentError = error.localizedDescription
            }

        case .failure(let error):
            environmentError = error.localizedDescription
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
            await coalescedLoadAssets()
        } catch {
            environmentError = error.localizedDescription
        }
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
            environmentError = error.localizedDescription
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
            environmentError = nil
        } catch {
            guard !Task.isCancelled else { return }
            environmentError = error.localizedDescription
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
                    environmentError = error.localizedDescription
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
                    environmentError = error.localizedDescription
                }
            }
        }
    }
}

private struct EnvironmentSettingsStatusLabel: View {
    let status: EnvironmentPreviewCardStatus

    var body: some View {
        if let chip = status.chip {
            Label(chip.title, systemImage: chip.systemImage)
                .font(.caption)
                .foregroundStyle(chip.tint)
        }
    }
}
