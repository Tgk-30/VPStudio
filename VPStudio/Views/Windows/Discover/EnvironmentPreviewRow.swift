import SwiftUI

#if os(visionOS)
import ImageIO
import UniformTypeIdentifiers

enum EnvironmentThumbnailDecodePolicy {
    static let shouldAllowFloatForPreview = false

    static func looksLikeCompleteJPEG(header: Data, trailer: Data?, fileSize: UInt64) -> Bool {
        guard header.starts(with: Data([0xFF, 0xD8, 0xFF])),
              fileSize >= 4,
              let trailer,
              trailer.count == 2 else {
            return false
        }
        return trailer == Data([0xFF, 0xD9])
    }
}

enum EnvironmentPreviewLayoutPolicy {
    static let cardWidth: CGFloat = 286
    static let cardHeight: CGFloat = 158
    static let cardCornerRadius: CGFloat = 16
    static let gridSpacing: CGFloat = 18
    static let maximumCenteredColumns = 4
    static let contentSpacing: CGFloat = 24
    static let contentHorizontalPadding: CGFloat = 24
    static let contentTopPadding: CGFloat = 24
    static let bottomContentPadding: CGFloat = 12
    static let pickerMinWidth: CGFloat = 720
    static let pickerPreferredWidth: CGFloat = 1_180
    static let pickerMinHeight: CGFloat = 456
    static let roomLegibilityBackdropOpacity: Double = 0.18
    static let roomLegibilityPanelOpacity: Double = 0.64
    static let roomLegibilityRowOpacity: Double = 0.60
    static let roomLegibilityStrokeOpacity: Double = 0.30
    static let roomLegibilitySecondaryTextOpacity: Double = 0.94
    static let closeButtonSize: CGFloat = 42

    static var roomLegibilitySecondaryText: Color {
        Color.white.opacity(roomLegibilitySecondaryTextOpacity)
    }

    static func gridColumns() -> [GridItem] {
        [
            GridItem(
                .adaptive(minimum: cardWidth, maximum: cardWidth),
                spacing: gridSpacing
            ),
        ]
    }

    static func gridContentMaxWidth(itemCount: Int, maximumColumns: Int = maximumCenteredColumns) -> CGFloat {
        let columnCount = min(max(itemCount, 1), max(maximumColumns, 1))
        return (CGFloat(columnCount) * cardWidth) + (CGFloat(columnCount - 1) * gridSpacing)
    }

    static var cardShape: RoundedRectangle {
        RoundedRectangle(cornerRadius: cardCornerRadius, style: .continuous)
    }
}

// MARK: - Sheet

/// Full-screen sheet that presents when the environment ornament button is tapped.
/// Shows environment cards in a grid so users can preview and manage them.
struct EnvironmentPickerSheet: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    @Environment(\.dismissImmersiveSpace) private var dismissImmersiveSpace

    let onSelect: (EnvironmentAsset) -> Void
    let onDismiss: () -> Void
    var onSelectCinema: (() -> Void)? = nil
    var onClear: (() -> Void)? = nil

    @State private var environments: [EnvironmentAsset] = []
    @State private var isShowingFileImporter = false
    @State private var isImportingEnvironment = false
    @State private var importError: String?
    @State private var environmentLoadTask: Task<Void, Never>?
    @State private var pendingDeletion: PendingDeletion?
    @State private var installingPresetIDs: Set<String> = []
    @State private var deletingAssetIDs: Set<String> = []
    private let disablesAutomaticTasks: Bool

    private let onlinePresets = EnvironmentCatalogManager.onlinePresets

    private struct PendingDeletion: Identifiable {
        let id: String
        let name: String
    }

    init(
        onSelect: @escaping (EnvironmentAsset) -> Void,
        onDismiss: @escaping () -> Void,
        onSelectCinema: (() -> Void)? = nil,
        onClear: (() -> Void)? = nil,
        initialEnvironments: [EnvironmentAsset] = [],
        initialImportError: String? = nil,
        disablesAutomaticTasks: Bool = false
    ) {
        self.onSelect = onSelect
        self.onDismiss = onDismiss
        self.onSelectCinema = onSelectCinema
        self.onClear = onClear
        _environments = State(initialValue: initialEnvironments)
        _importError = State(initialValue: initialImportError)
        self.disablesAutomaticTasks = disablesAutomaticTasks
    }

    var body: some View {
        ViewThatFits(in: .vertical) {
            pickerContent
            ScrollView {
                pickerContent
            }
        }
        .background {
            ZStack {
                VPEnvironmentBackdrop(includesMaterial: false)
                Color.black.opacity(EnvironmentPreviewLayoutPolicy.roomLegibilityBackdropOpacity)
            }
        }
        .presentationBackground(.clear)
        .presentationSizing(.fitted)
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
        .fileImporter(
            isPresented: $isShowingFileImporter,
            allowedContentTypes: Self.environmentContentTypes,
            allowsMultipleSelection: false
        ) { result in
            Task { await handleFileImport(result) }
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
                Task { await deleteAsset(id: deletion.id) }
            }
            Button("Cancel", role: .cancel) {}
        } message: { deletion in
            Text("Delete \(deletion.name)? This removes the imported environment from disk.")
        }
    }

    // MARK: - Content Types

    private static var environmentContentTypes: [UTType] {
        EnvironmentImportValidationPolicy.supportedExtensionOrder
            .compactMap { UTType(filenameExtension: $0) }
    }

    // MARK: - Sub-views

    private var pickerContent: some View {
        VStack(alignment: .leading, spacing: EnvironmentPreviewLayoutPolicy.contentSpacing) {
            header
            environmentGrid
            environmentStatusPanel

            if EnvironmentPreviewRowPolicy.shouldShowImportPrompt(environments: environments) {
                importPrompt
            }

            if appState.isImmersiveSpaceOpen {
                exitButton
            }

            onlinePresetsSection

            if let error = importError {
                importErrorBanner(error)
            }
        }
        .padding(.horizontal, EnvironmentPreviewLayoutPolicy.contentHorizontalPadding)
        .padding(.top, EnvironmentPreviewLayoutPolicy.contentTopPadding)
        .padding(.bottom, EnvironmentPreviewLayoutPolicy.bottomContentPadding)
        .frame(
            minWidth: EnvironmentPreviewLayoutPolicy.pickerMinWidth,
            idealWidth: EnvironmentPreviewLayoutPolicy.pickerPreferredWidth,
            maxWidth: EnvironmentPreviewLayoutPolicy.pickerPreferredWidth,
            minHeight: EnvironmentPreviewLayoutPolicy.pickerMinHeight,
            alignment: .topLeading
        )
    }

    private var header: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .top, spacing: 18) {
                headerTitleBlock
                Spacer(minLength: 16)
                headerActions
            }

            VStack(alignment: .leading, spacing: 14) {
                headerTitleBlock
                headerActions
            }
        }
    }

    private var headerTitleBlock: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Environments")
                .font(.largeTitle.weight(.bold))
                .foregroundStyle(VPColor.textPrimary)

            Text(EnvironmentPreviewRowPolicy.appleEnvironmentPickerSubtitle)
                .font(.subheadline)
                .foregroundStyle(EnvironmentPreviewLayoutPolicy.roomLegibilitySecondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var headerActions: some View {
        HStack(spacing: 10) {
            Button {
                isShowingFileImporter = true
            } label: {
                importButtonLabel
            }
            .buttonStyle(.borderedProminent)
            .disabled(isImportingEnvironment)

            closeButton
        }
    }

    private var closeButton: some View {
        Button {
            dismiss()
        } label: {
            Image(systemName: "xmark.circle.fill")
                .font(.title3.weight(.semibold))
                .symbolRenderingMode(.hierarchical)
                .frame(
                    width: EnvironmentPreviewLayoutPolicy.closeButtonSize,
                    height: EnvironmentPreviewLayoutPolicy.closeButtonSize
                )
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(VPColor.textPrimary)
        .accessibilityLabel("Close environments")
        .accessibilityHint("Closes the environment picker.")
    }

    private var environmentGrid: some View {
        let selectedAssetID = EnvironmentPreviewRowPolicy.effectiveSelectedAssetID(
            appStateSelectedID: appState.selectedEnvironmentAsset?.id,
            assets: environments
        )
        let itemCount = 2 + environments.count
        return LazyVGrid(
            columns: EnvironmentPreviewLayoutPolicy.gridColumns(),
            spacing: EnvironmentPreviewLayoutPolicy.gridSpacing
        ) {
            NoEnvironmentPreviewCard(
                status: EnvironmentPreviewRowPolicy.standardRoomStatus(
                    selectedAssetID: selectedAssetID,
                    activeEnvironment: appState.activeEnvironment,
                    isImmersiveSpaceOpen: appState.isImmersiveSpaceOpen
                ),
                onSelect: {
                    onClear?()
                    dismiss()
                }
            )
            .disabled(onClear == nil)

            CinemaEnvironmentPreviewCard(
                status: EnvironmentPreviewRowPolicy.cinemaStatus(
                    activeEnvironment: appState.activeEnvironment,
                    isImmersiveSpaceOpen: appState.isImmersiveSpaceOpen
                ),
                onSelect: {
                    onSelectCinema?()
                    dismiss()
                }
            )
            .disabled(onSelectCinema == nil)

            ForEach(environments) { asset in
                let isDeleting = isDeletingAsset(asset)
                EnvironmentPreviewCard(
                    asset: asset,
                    status: EnvironmentPreviewRowPolicy.assetStatus(
                        assetID: asset.id,
                        selectedAssetID: selectedAssetID,
                        activeEnvironment: appState.activeEnvironment,
                        isImmersiveSpaceOpen: appState.isImmersiveSpaceOpen
                    ),
                    isDeleting: isDeleting,
                    managedImportedAssetDirectory: appState.environmentCatalogManager.managedImportedAssetsDirectory,
                    onSelect: {
                        guard !isDeleting else { return }
                        onSelect(asset)
                        dismiss()
                    },
                    onDelete: asset.sourceType == .imported && !isDeleting ? {
                        pendingDeletion = PendingDeletion(id: asset.id, name: asset.name)
                    } : nil
                )
            }
        }
        .frame(maxWidth: EnvironmentPreviewLayoutPolicy.gridContentMaxWidth(itemCount: itemCount))
        .frame(maxWidth: .infinity, alignment: .center)
    }

    private var environmentStatusPanel: some View {
        HStack(alignment: .center, spacing: 14) {
            Image(systemName: environmentStatusIconName)
                .font(.title3.weight(.semibold))
                .foregroundStyle(appState.isImmersiveSpaceOpen ? VPColor.success : VPColor.info)
                .frame(width: 42, height: 42)
                .background(VPColor.contentPlane.opacity(0.56), in: Circle())

            VStack(alignment: .leading, spacing: 3) {
                Text(environmentStatusTitle)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(VPColor.textPrimary)
                Text(environmentStatusDescription)
                    .font(.subheadline)
                    .foregroundStyle(EnvironmentPreviewLayoutPolicy.roomLegibilitySecondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .layoutPriority(1)

            Spacer(minLength: 12)

            if appState.isImmersiveSpaceOpen || (effectiveSelectedEnvironmentAssetID != nil && onClear != nil) {
                Button(role: appState.isImmersiveSpaceOpen ? .destructive : nil) {
                    if appState.isImmersiveSpaceOpen {
                        onDismiss()
                    } else {
                        onClear?()
                    }
                    dismiss()
                } label: {
                    Label(
                        appState.isImmersiveSpaceOpen ? "Exit Environment" : "Use Apple Environment",
                        systemImage: appState.isImmersiveSpaceOpen ? "xmark.circle" : "visionpro"
                    )
                }
                .buttonStyle(VPButtonStyle(kind: appState.isImmersiveSpaceOpen ? .destructive : .secondary))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 22)
        .background {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(.regularMaterial)
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(VPColor.contentPlane.opacity(EnvironmentPreviewLayoutPolicy.roomLegibilityPanelOpacity))
        }
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(.white.opacity(EnvironmentPreviewLayoutPolicy.roomLegibilityStrokeOpacity), lineWidth: 1)
        }
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .frame(maxWidth: EnvironmentPreviewLayoutPolicy.gridContentMaxWidth(itemCount: 4))
        .frame(maxWidth: .infinity, alignment: .center)
    }

    private var exitButton: some View {
        HStack {
            Spacer(minLength: 0)

            Button(role: .destructive) {
                onDismiss()
                dismiss()
            } label: {
                Label("Exit Environment", systemImage: "xmark.circle")
            }
            .buttonStyle(VPButtonStyle(kind: .destructive))

            Spacer(minLength: 0)
        }
        .padding(.top, 2)
    }

    private var effectiveSelectedEnvironmentAssetID: String? {
        EnvironmentPreviewRowPolicy.effectiveSelectedAssetID(
            appStateSelectedID: appState.selectedEnvironmentAsset?.id,
            assets: environments
        )
    }

    private var effectiveSelectedEnvironmentAsset: EnvironmentAsset? {
        EnvironmentPreviewRowPolicy.effectiveSelectedAsset(
            appStateSelectedAsset: appState.selectedEnvironmentAsset,
            assets: environments
        )
    }

    private var environmentStatusTitle: String {
        if appState.isImmersiveSpaceOpen {
            if appState.activeEnvironment == .cinemaEnvironment {
                return "Cinema Environment is active"
            }
            if let selected = effectiveSelectedEnvironmentAsset {
                return "\(selected.name) is active"
            }
            return "Environment is active"
        }

        if let selected = effectiveSelectedEnvironmentAsset {
            return "\(selected.name) is selected"
        }

        return EnvironmentPreviewRowPolicy.appleEnvironmentSelectedTitle
    }

    private var environmentStatusDescription: String {
        if appState.isImmersiveSpaceOpen {
            return "This environment is currently open. Exit it before switching back to Apple Environment."
        }

        if effectiveSelectedEnvironmentAssetID != nil {
            return "The selected environment will open when playback starts."
        }

        return EnvironmentPreviewRowPolicy.appleEnvironmentSelectedBody
    }

    private var environmentStatusIconName: String {
        if appState.activeEnvironment == .cinemaEnvironment {
            return "theatermasks"
        }
        if effectiveSelectedEnvironmentAssetID != nil {
            return "mountain.2"
        }
        return "visionpro"
    }

    private var importPrompt: some View {
        HStack(spacing: 16) {
            Image(systemName: "mountain.2")
                .font(.system(size: 30, weight: .semibold))
                .foregroundStyle(EnvironmentPreviewLayoutPolicy.roomLegibilitySecondaryText)
                .frame(width: 44, height: 44)
                .background(VPColor.contentPlane.opacity(0.42), in: Circle())

            VStack(alignment: .leading, spacing: 4) {
                Text("No imported environments")
                    .font(.headline)
                    .foregroundStyle(VPColor.textPrimary)
                Text("Import \(EnvironmentImportValidationPolicy.supportedExtensionDisplayList) files to build a reusable playback environment library.")
                    .font(.subheadline)
                    .foregroundStyle(EnvironmentPreviewLayoutPolicy.roomLegibilitySecondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 16)

            Button {
                isShowingFileImporter = true
            } label: {
                importButtonLabel
            }
            .buttonStyle(.borderedProminent)
            .disabled(isImportingEnvironment)
        }
        .frame(maxWidth: .infinity)
        .padding(18)
        .background {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(.thinMaterial)
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(VPColor.contentPlane.opacity(EnvironmentPreviewLayoutPolicy.roomLegibilityRowOpacity))
        }
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(.white.opacity(EnvironmentPreviewLayoutPolicy.roomLegibilityStrokeOpacity), lineWidth: 1)
        }
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    @ViewBuilder
    private var importButtonLabel: some View {
        if isImportingEnvironment {
            HStack(spacing: 8) {
                ProgressView()
                    .controlSize(.small)
                Text("Importing")
            }
        } else {
            Label("Import", systemImage: "plus.circle")
        }
    }

    @ViewBuilder
    private var onlinePresetsSection: some View {
        if !onlinePresets.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("More Environments")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(VPColor.textPrimary)
                    Text("One-click import curated Poly Haven HDRI panoramas, then open them from this list or the cards above.")
                        .font(.subheadline)
                        .foregroundStyle(EnvironmentPreviewLayoutPolicy.roomLegibilitySecondaryText)
                }

                ForEach(onlinePresets) { preset in
                    onlinePresetRow(preset)
                }
            }
        }
    }

    @ViewBuilder
    private func onlinePresetRow(_ preset: CuratedEnvironmentPreset) -> some View {
        let installedAsset = installedPresetAsset(preset)
        let isInstalled = isPresetInstalled(preset)
        let isInstalling = installingPresetIDs.contains(preset.id)

        HStack(alignment: .center, spacing: 14) {
            Image(systemName: EnvironmentPreviewRowPolicy.providerIconName(for: preset.provider))
                .font(.title3)
                .frame(width: 34, height: 34)
                .foregroundStyle(EnvironmentPreviewLayoutPolicy.roomLegibilitySecondaryText)
                .background(VPColor.contentPlane.opacity(0.42), in: Circle())

            VStack(alignment: .leading, spacing: 3) {
                Text(preset.name)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(VPColor.textPrimary)
                Text(preset.description)
                    .font(.subheadline)
                    .foregroundStyle(EnvironmentPreviewLayoutPolicy.roomLegibilitySecondaryText)
                Text("\(preset.provider.displayName) • \(preset.licenseName)")
                    .font(.caption)
                    .foregroundStyle(EnvironmentPreviewLayoutPolicy.roomLegibilitySecondaryText)
            }
            .layoutPriority(1)

            Spacer(minLength: 12)

            if isInstalled, let installedAsset {
                VStack(alignment: .trailing, spacing: 8) {
                    Label("Added", systemImage: "checkmark.circle.fill")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(VPColor.success)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 7)
                        .background(VPColor.success.opacity(0.12), in: Capsule())

                    Button {
                        onSelect(installedAsset)
                        dismiss()
                    } label: {
                        Label("Open", systemImage: "play.circle")
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.regular)
                    .frame(minWidth: 92)
                }
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
                .controlSize(.regular)
                .frame(minWidth: 92)
                .disabled(isInstalling)
            }
        }
        .padding(16)
        .background {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(.thinMaterial)
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(VPColor.contentPlane.opacity(EnvironmentPreviewLayoutPolicy.roomLegibilityRowOpacity))
        }
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(.white.opacity(EnvironmentPreviewLayoutPolicy.roomLegibilityStrokeOpacity), lineWidth: 1)
        }
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func importErrorBanner(_ message: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(VPColor.warning)
            Text(message)
                .font(.caption)
                .foregroundStyle(EnvironmentPreviewLayoutPolicy.roomLegibilitySecondaryText)
            Spacer()
            Button("Dismiss") { importError = nil }
                .font(.caption)
        }
        .padding(12)
        .background {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(.thinMaterial)
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(VPColor.contentPlane.opacity(EnvironmentPreviewLayoutPolicy.roomLegibilityRowOpacity))
        }
        .overlay {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(.white.opacity(EnvironmentPreviewLayoutPolicy.roomLegibilityStrokeOpacity), lineWidth: 1)
        }
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    // MARK: - Actions

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
        do {
            let latestEnvironments = try await appState.environmentCatalogManager.fetchAssets()
            guard !Task.isCancelled else { return }
            environments = latestEnvironments
            appState.reconcileEnvironmentSelection(withLoadedAssets: latestEnvironments)
            importError = nil
        } catch {
            guard !Task.isCancelled else { return }
            importError = EnvironmentErrorPresentationPolicy.displayMessage(for: error)
        }
    }

    @MainActor
    private func handleFileImport(_ result: Result<[URL], Error>) async {
        guard !isImportingEnvironment else { return }
        importError = nil
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
                await coalescedLoadEnvironments()
            } catch {
                importError = EnvironmentErrorPresentationPolicy.displayMessage(for: error)
            }

        case .failure(let error):
            importError = EnvironmentErrorPresentationPolicy.displayMessage(for: error)
        }
    }

    private func isDeletingAsset(_ asset: EnvironmentAsset) -> Bool {
        deletingAssetIDs.contains(normalizedAssetID(asset.id))
    }

    private func normalizedAssetID(_ id: String) -> String {
        id.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func isPresetInstalled(_ preset: CuratedEnvironmentPreset) -> Bool {
        installedPresetAsset(preset) != nil
    }

    private func installedPresetAsset(_ preset: CuratedEnvironmentPreset) -> EnvironmentAsset? {
        environments.first { environment in
            environment.sourceType == .imported
                && environment.name == preset.name
                && environment.sourceAttributionURL == preset.sourceAttributionURL
        }
    }

    @discardableResult
    @MainActor
    private func clearActiveEnvironment() async -> Bool {
        if appState.isImmersiveSpaceOpen {
            guard appState.beginImmersiveTransition() else { return false }
            appState.stageImmersiveDismiss(reason: .userInitiated)
            await dismissImmersiveSpace()
            appState.completeImmersiveDismissIfStillPending()
        }

        await appState.clearEnvironmentSelection()
        await coalescedLoadEnvironments()
        return true
    }

    @MainActor
    private func deleteAsset(id: String) async {
        let normalizedID = normalizedAssetID(id)
        guard !normalizedID.isEmpty,
              !deletingAssetIDs.contains(normalizedID) else {
            return
        }

        importError = nil
        deletingAssetIDs.insert(normalizedID)
        defer { deletingAssetIDs.remove(normalizedID) }

        do {
            let isActiveSelection = EnvironmentPreviewRowPolicy.shouldClearActiveSelection(
                deleting: normalizedID,
                selectedAssetID: appState.selectedEnvironmentAsset?.id,
                assets: environments
            )
            if isActiveSelection {
                guard await clearActiveEnvironment() else {
                    importError = "Finish the current environment transition before deleting this environment."
                    return
                }
            }
            try await appState.environmentCatalogManager.deleteAsset(id: normalizedID)
            await coalescedLoadEnvironments()
        } catch {
            importError = EnvironmentErrorPresentationPolicy.deleteFailureMessage(for: error)
        }
    }

    @MainActor
    private func installPreset(_ preset: CuratedEnvironmentPreset) async {
        guard !isPresetInstalled(preset),
              !installingPresetIDs.contains(preset.id) else {
            return
        }

        importError = nil
        installingPresetIDs.insert(preset.id)
        defer { installingPresetIDs.remove(preset.id) }

        do {
            let importedAsset = try await appState.environmentCatalogManager.importCuratedPreset(preset)
            await coalescedLoadEnvironments()
            if installedPresetAsset(preset) == nil {
                environments.append(importedAsset)
            }
        } catch {
            importError = EnvironmentErrorPresentationPolicy.displayMessage(for: error)
        }
    }
}

// MARK: - Card

struct EnvironmentPreviewCard: View {
    let asset: EnvironmentAsset
    let status: EnvironmentPreviewCardStatus
    var isDeleting: Bool = false
    var managedImportedAssetDirectory: URL? = nil
    let onSelect: () -> Void
    var onDelete: (() -> Void)? = nil

    @State private var thumbnailImage: CGImage?
    @State private var thumbnailImageSourceID: String?
    @State private var thumbnailFailed = false
    @State private var thumbnailLoadingSourceID: String?
    @State private var thumbnailLoadTask: Task<Void, Never>?

    var body: some View {
        Button(action: onSelect) {
            ZStack(alignment: .bottomLeading) {
                previewBackground
                    .frame(width: EnvironmentPreviewLayoutPolicy.cardWidth, height: EnvironmentPreviewLayoutPolicy.cardHeight)
                    .clipShape(EnvironmentPreviewLayoutPolicy.cardShape)

                LinearGradient(
                    stops: [
                        .init(color: .clear, location: 0.0),
                        .init(color: .black.opacity(0.22), location: 0.36),
                        .init(color: .black.opacity(0.62), location: 0.64),
                        .init(color: .black.opacity(0.88), location: 1.0),
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .clipShape(EnvironmentPreviewLayoutPolicy.cardShape)

                VStack(alignment: .leading, spacing: 5) {
                    EnvironmentPreviewCardTitleText(asset.name)
                    HStack(spacing: 5) {
                        Image(systemName: EnvironmentPreviewRowPolicy.assetTypeIconName(forAssetPath: asset.assetPath))
                            .font(.caption2)
                            .foregroundStyle(.white.opacity(0.86))
                        Text(EnvironmentPreviewRowPolicy.assetTypeLabel(
                            sourceType: asset.sourceType,
                            assetPath: asset.assetPath
                        ))
                            .font(.caption2)
                            .foregroundStyle(.white.opacity(0.86))
                    }
                }
                .padding(16)
                .shadow(color: .black.opacity(0.55), radius: 2, y: 1)
            }
            .frame(width: EnvironmentPreviewLayoutPolicy.cardWidth, height: EnvironmentPreviewLayoutPolicy.cardHeight)
        }
        .buttonStyle(.plain)
        .disabled(isDeleting)
        .overlay {
            EnvironmentPreviewLayoutPolicy.cardShape
                .strokeBorder(
                    LinearGradient(
                        colors: status.borderGradientColors,
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: status.isHighlighted ? 2.5 : 1
                )
        }
        .overlay(alignment: .topTrailing) {
            if isDeleting {
                EnvironmentStatusChip(
                    title: "Deleting",
                    systemImage: "hourglass",
                    tint: .secondary
                )
                .padding(10)
                .transition(.scale(0.7).combined(with: .opacity))
            } else if let chip = status.chip {
                EnvironmentStatusChip(
                    title: chip.title,
                    systemImage: chip.systemImage,
                    tint: chip.tint
                )
                .padding(10)
                .transition(.scale(0.7).combined(with: .opacity))
            }
        }
        // Thumbnail load failure warning
        .overlay(alignment: .topLeading) {
            if isDeleting {
                ProgressView()
                    .controlSize(.small)
                    .padding(10)
            } else if isLoadingThumbnail {
                ProgressView()
                    .controlSize(.small)
                    .tint(.white)
                    .padding(10)
                    .background(.black.opacity(0.32), in: Circle())
                    .transition(.opacity)
            } else if thumbnailFailed && EnvironmentPreviewRowPolicy.isHDRIAsset(assetPath: asset.assetPath) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundStyle(VPColor.warning)
                    .padding(10)
            }
        }
        .shadow(color: .black.opacity(0.07), radius: 24)
        .shadow(
            color: status.isHighlighted ? VPColor.accent.opacity(0.28) : .black.opacity(0.16),
            radius: 8,
            y: 4
        )
        .opacity(isDeleting ? 0.72 : 1.0)
        .animation(.easeInOut(duration: 0.18), value: thumbnailImageSourceID)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: status)
        .animation(.easeInOut(duration: 0.18), value: isDeleting)
        .hoverEffect(.lift)
        .task(id: EnvironmentPreviewRowPolicy.thumbnailLoadID(for: asset)) {
            thumbnailLoadTask?.cancel()
            thumbnailLoadTask = Task { await loadThumbnail() }
            await thumbnailLoadTask?.value
        }
        .onDisappear {
            thumbnailLoadTask?.cancel()
            thumbnailLoadTask = nil
        }
        .contextMenu {
            if let onDelete, !isDeleting {
                Button(role: .destructive) {
                    onDelete()
                } label: {
                    Label("Delete", systemImage: "trash")
                }
            }
        }
    }

    // MARK: Background

    private var isLoadingThumbnail: Bool {
        thumbnailImage == nil
            && thumbnailLoadingSourceID == EnvironmentPreviewRowPolicy.thumbnailLoadID(for: asset)
    }

    @ViewBuilder
    private var previewBackground: some View {
        if let image = thumbnailImage {
            Image(image, scale: 1.0, label: Text(asset.name))
                .resizable()
                .aspectRatio(contentMode: .fill)
                .transition(.opacity)
        } else {
            placeholderGradient
                .transition(.opacity)
        }
    }

    private var placeholderGradient: some View {
        EnvironmentPreviewFallbackArtworkView(
            kind: EnvironmentPreviewRowPolicy.fallbackArtworkKind(
                sourceType: asset.sourceType,
                assetPath: asset.assetPath
            ),
            paletteIndex: EnvironmentPreviewRowPolicy.fallbackPaletteIndex(for: asset)
        )
    }

    // MARK: Thumbnail

    private func loadThumbnail() async {
        thumbnailFailed = false
        let paths = EnvironmentPreviewRowPolicy.thumbnailSourcePaths(for: asset)
        let loadID = EnvironmentPreviewRowPolicy.thumbnailLoadID(for: asset)
        guard !paths.isEmpty else {
            thumbnailImage = nil
            thumbnailImageSourceID = nil
            if thumbnailLoadingSourceID == loadID {
                thumbnailLoadingSourceID = nil
            }
            return
        }
        thumbnailLoadingSourceID = loadID
        defer {
            if thumbnailLoadingSourceID == loadID {
                thumbnailLoadingSourceID = nil
            }
        }

        let managedImportedAssetDirectory = managedImportedAssetDirectory
        let decodeTask = Task.detached(priority: .userInitiated) { () -> CGImage? in
            if Task.isCancelled {
                return nil
            }
            for path in paths {
                guard let url = Self.thumbnailURL(
                    for: path,
                    managedImportedAssetDirectory: managedImportedAssetDirectory
                ),
                      EnvironmentPreviewRowPolicy.isReadableThumbnailFile(url) else {
                    continue
                }
                if let image = Self.loadHDRThumbnail(from: url, maxDimension: 512) {
                    return image
                }
            }
            return nil
        }

        let image = await withTaskCancellationHandler(
            operation: {
                await decodeTask.value
            },
            onCancel: {
                decodeTask.cancel()
            }
        )

        guard !Task.isCancelled else { return }

        if let image {
            thumbnailImage = image
            thumbnailImageSourceID = loadID
        } else {
            if thumbnailImageSourceID != loadID {
                thumbnailImage = nil
                thumbnailImageSourceID = nil
            }
            thumbnailFailed = true
        }
    }

    nonisolated private static func thumbnailURL(
        for path: String,
        managedImportedAssetDirectory: URL?
    ) -> URL? {
        if path.hasPrefix("bundle://") {
            return bundledResourceURL(relativePath: String(path.dropFirst("bundle://".count)))
        }
        guard let fileURL = EnvironmentURLPolicy.absoluteFileURL(fromStoredPath: path) else {
            return nil
        }
        if let managedImportedAssetDirectory {
            guard EnvironmentURLPolicy.fileURL(fileURL, isInside: managedImportedAssetDirectory) else {
                return nil
            }
        }
        return fileURL.standardizedFileURL
    }

    nonisolated private static func bundledResourceURL(relativePath: String) -> URL? {
        EnvironmentURLPolicy.bundleResourceURL(relativePath: relativePath, in: .main)
    }

    nonisolated private static func loadHDRThumbnail(from url: URL, maxDimension: Int) -> CGImage? {
        guard fileLooksDecodableByImageIO(url: url) else { return nil }
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
        guard imageSourceHasReadableImage(at: source, index: 0) else { return nil }

        let thumbOptions: [CFString: Any] = [
            kCGImageSourceShouldCache: false,
            kCGImageSourceShouldAllowFloat: EnvironmentThumbnailDecodePolicy.shouldAllowFloatForPreview,
            kCGImageSourceThumbnailMaxPixelSize: maxDimension,
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
        ]
        if let thumb = CGImageSourceCreateThumbnailAtIndex(source, 0, thumbOptions as CFDictionary) {
            return thumb
        }

        let fullOptions: [CFString: Any] = [
            kCGImageSourceShouldCache: false,
            kCGImageSourceShouldAllowFloat: EnvironmentThumbnailDecodePolicy.shouldAllowFloatForPreview,
        ]
        return CGImageSourceCreateImageAtIndex(source, 0, fullOptions as CFDictionary)
    }

    nonisolated private static func fileLooksDecodableByImageIO(url: URL) -> Bool {
        var isDirectory = ObjCBool(false)
        guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory),
              !isDirectory.boolValue,
              FileManager.default.isReadableFile(atPath: url.path) else {
            return false
        }

        let fileSize = fileSize(at: url)
        guard fileSize > 0,
              let header = readPrefix(at: url, count: 512),
              !header.isEmpty else {
            return false
        }

        if header.starts(with: Data([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A])) {
            guard fileSize >= 12,
                  let trailer = readSuffix(at: url, count: 12),
                  trailer.count == 12 else {
                return false
            }
            let chunkType = trailer[
                trailer.index(trailer.startIndex, offsetBy: 4)..<trailer.index(trailer.startIndex, offsetBy: 8)
            ]
            return Data(chunkType) == Data("IEND".utf8)
        }

        if EnvironmentThumbnailDecodePolicy.looksLikeCompleteJPEG(
            header: header,
            trailer: readSuffix(at: url, count: 2),
            fileSize: fileSize
        ) {
            return true
        }

        if header.starts(with: Data([0x76, 0x2F, 0x31, 0x01])) {
            return fileSize > 32
        }

        if let asciiHeader = String(data: header, encoding: .ascii),
           asciiHeader.hasPrefix("#?RADIANCE") || asciiHeader.hasPrefix("#?RGBE") {
            return asciiHeader.contains("FORMAT=")
        }

        return false
    }

    nonisolated private static func fileSize(at url: URL) -> UInt64 {
        let values = try? url.resourceValues(forKeys: [.fileSizeKey])
        return UInt64(max(values?.fileSize ?? 0, 0))
    }

    nonisolated private static func readPrefix(at url: URL, count: Int) -> Data? {
        guard let handle = try? FileHandle(forReadingFrom: url) else { return nil }
        defer { try? handle.close() }
        return try? handle.read(upToCount: count) ?? Data()
    }

    nonisolated private static func readSuffix(at url: URL, count: Int) -> Data? {
        guard let handle = try? FileHandle(forReadingFrom: url) else { return nil }
        defer { try? handle.close() }
        guard let end = try? handle.seekToEnd() else { return nil }
        let offset = end > UInt64(count) ? end - UInt64(count) : 0
        do {
            try handle.seek(toOffset: offset)
            return try handle.read(upToCount: count) ?? Data()
        } catch {
            return nil
        }
    }

    nonisolated private static func imageSourceHasReadableImage(at source: CGImageSource, index: Int) -> Bool {
        guard CGImageSourceGetCount(source) > index else { return false }
        guard let properties = CGImageSourceCopyPropertiesAtIndex(source, index, nil) as? [CFString: Any] else {
            return false
        }

        let width = imageDimension(from: properties[kCGImagePropertyPixelWidth])
        let height = imageDimension(from: properties[kCGImagePropertyPixelHeight])
        return width > 0 && height > 0
    }

    nonisolated private static func imageDimension(from value: Any?) -> Int {
        switch value {
        case let number as NSNumber:
            return number.intValue
        case let intValue as Int:
            return intValue
        default:
            return 0
        }
    }
}

#endif

enum EnvironmentPreviewCardStatus: Equatable, Sendable {
    case inactive
    case current
    case selected
    case active

    var isHighlighted: Bool {
        self != .inactive
    }

    var chip: (title: String, systemImage: String, tint: Color)? {
        switch self {
        case .inactive:
            return nil
        case .current:
            return ("Current", "checkmark.circle.fill", VPColor.accent)
        case .selected:
            return ("Selected", "checkmark.circle", VPColor.info)
        case .active:
            return ("Active", "play.circle.fill", VPColor.success)
        }
    }

    var borderGradientColors: [Color] {
        switch self {
        case .inactive:
            return [.white.opacity(0.18), .white.opacity(0.04)]
        case .current:
            return [VPColor.accent.opacity(0.95), VPColor.accent.opacity(0.5)]
        case .selected:
            return [VPColor.info.opacity(0.95), VPColor.info.opacity(0.46)]
        case .active:
            return [VPColor.success.opacity(0.95), VPColor.success.opacity(0.48)]
        }
    }
}

enum EnvironmentPreviewFallbackArtworkKind: Equatable, Sendable {
    case standardRoom
    case cinema
    case bundledEnvironment
    case panorama
    case scene

    var iconName: String {
        switch self {
        case .standardRoom:
            return "visionpro"
        case .cinema:
            return "theatermasks.fill"
        case .bundledEnvironment:
            return "sparkles"
        case .panorama:
            return "pano.fill"
        case .scene:
            return "cube.transparent.fill"
        }
    }

    var iconOpacity: Double {
        switch self {
        case .standardRoom:
            return 0.64
        case .cinema:
            return 0.68
        case .bundledEnvironment:
            return 0.70
        case .panorama:
            return 0.72
        case .scene:
            return 0.68
        }
    }
}

enum EnvironmentPreviewRowPolicy {
    static let appleEnvironmentTitle = "Apple Environment"
    static let appleEnvironmentTypeLabel = "System window"
    static let appleEnvironmentBenefitLabel = "System expansion when available"
    static let appleEnvironmentDetailText = "Keeps playback in the visionOS system window."
    static let appleEnvironmentPickerSubtitle = "Choose a VPStudio playback environment, or keep Apple Environment for the system window. System expansion and room effects are available only when playback uses the system video surface."
    static let appleEnvironmentSelectedTitle = "Apple Environment selected"
    static let appleEnvironmentSelectedBody = "Playback stays in a system-owned window. System expansion and room effects are available with supported playback."

    static func shouldShowImportPrompt(environments: [EnvironmentAsset]) -> Bool {
        !environments.contains { $0.sourceType == .imported }
    }

    static func effectiveSelectedAssetID(
        appStateSelectedID: String?,
        assets: [EnvironmentAsset]
    ) -> String? {
        let appStateID = normalizedID(appStateSelectedID)
        if !appStateID.isEmpty {
            if assets.isEmpty || assets.contains(where: { normalizedID($0.id) == appStateID }) {
                return appStateID
            }
        }

        return assets.first { asset in
            asset.isActive && !normalizedID(asset.id).isEmpty
        }.map(\.id)
    }

    static func effectiveSelectedAsset(
        appStateSelectedAsset: EnvironmentAsset?,
        assets: [EnvironmentAsset]
    ) -> EnvironmentAsset? {
        if let appStateSelectedAsset,
           !normalizedID(appStateSelectedAsset.id).isEmpty {
            let appStateID = normalizedID(appStateSelectedAsset.id)
            if let catalogAsset = assets.first(where: { normalizedID($0.id) == appStateID }) {
                return catalogAsset
            }
            if assets.isEmpty {
                return appStateSelectedAsset
            }
        }

        guard let selectedID = effectiveSelectedAssetID(
            appStateSelectedID: appStateSelectedAsset?.id,
            assets: assets
        ) else {
            return nil
        }

        return assets.first { normalizedID($0.id) == selectedID }
    }

    static func providerIconName(for provider: CuratedEnvironmentProvider) -> String {
        switch provider {
        case .official:
            return "checkmark.seal"
        case .github:
            return "shippingbox"
        case .polyHaven:
            return "pano"
        }
    }

    static func standardRoomStatus(
        selectedAssetID: String?,
        activeEnvironment: EnvironmentType?,
        isImmersiveSpaceOpen: Bool
    ) -> EnvironmentPreviewCardStatus {
        guard activeEnvironment == nil else { return .inactive }
        guard !isImmersiveSpaceOpen else { return .inactive }
        return hasSelectedAssetID(selectedAssetID) ? .inactive : .current
    }

    static func cinemaStatus(
        activeEnvironment: EnvironmentType?,
        isImmersiveSpaceOpen: Bool
    ) -> EnvironmentPreviewCardStatus {
        activeEnvironment == .cinemaEnvironment && isImmersiveSpaceOpen ? .active : .inactive
    }

    static func assetStatus(
        assetID: String,
        selectedAssetID: String?,
        activeEnvironment: EnvironmentType?,
        isImmersiveSpaceOpen: Bool
    ) -> EnvironmentPreviewCardStatus {
        let normalizedAssetID = normalizedID(assetID)
        guard !normalizedAssetID.isEmpty,
              normalizedAssetID == normalizedID(selectedAssetID) else {
            return .inactive
        }
        guard isImmersiveSpaceOpen else { return .selected }
        switch activeEnvironment {
        case .customEnvironment, .hdriSkybox:
            return .active
        case .cinemaEnvironment, nil:
            return .selected
        }
    }

    static func isHDRIAsset(assetPath: String) -> Bool {
        let ext = URL(fileURLWithPath: assetPath).pathExtension.lowercased()
        // Must match the broadened skybox import (hdr/exr + equirectangular png/jpg) so 360
        // skyboxes aren't mislabeled "3D Scene" with a cube icon and no thumbnail.
        return ["hdr", "exr", "png", "jpg", "jpeg"].contains(ext)
    }

    static func isHDRAsset(assetPath: String) -> Bool {
        ["hdr", "exr"].contains(URL(fileURLWithPath: assetPath).pathExtension.lowercased())
    }

    static func assetTypeIconName(forAssetPath assetPath: String) -> String {
        isHDRIAsset(assetPath: assetPath) ? "pano" : "cube.transparent"
    }

    static func fallbackArtworkKind(
        sourceType: EnvironmentAssetSourceType,
        assetPath: String
    ) -> EnvironmentPreviewFallbackArtworkKind {
        if sourceType == .bundled {
            return .bundledEnvironment
        }
        return isHDRIAsset(assetPath: assetPath) ? .panorama : .scene
    }

    static func fallbackPaletteIndex(for asset: EnvironmentAsset, paletteCount: Int = 4) -> Int {
        guard paletteCount > 0 else { return 0 }
        let seed = "\(asset.id)|\(asset.name)|\(asset.assetPath)"
        var hash: UInt64 = 1_469_598_103_934_665_603
        for byte in seed.utf8 {
            hash = (hash ^ UInt64(byte)) &* 1_099_511_628_211
        }
        return Int(hash % UInt64(paletteCount))
    }

    static func assetTypeLabel(sourceType: EnvironmentAssetSourceType, assetPath: String) -> String {
        if sourceType == .bundled {
            return "Built-in"
        }
        if isHDRAsset(assetPath: assetPath) {
            return "HDRI"
        }
        if isHDRIAsset(assetPath: assetPath) {
            return "Panorama"
        }
        return "3D Scene"
    }

    static func assetDetailLabel(for asset: EnvironmentAsset) -> String {
        let typeLabel = assetTypeLabel(sourceType: asset.sourceType, assetPath: asset.assetPath)
        guard asset.sourceType == .imported,
              let fileName = importedFileNameLabel(assetPath: asset.assetPath) else {
            return typeLabel
        }
        return "\(typeLabel) • \(fileName)"
    }

    private static func importedFileNameLabel(assetPath: String) -> String? {
        let trimmedPath = assetPath.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedPath.isEmpty else { return nil }
        let fileName = URL(fileURLWithPath: trimmedPath).lastPathComponent
        let decodedFileName = fileName.removingPercentEncoding ?? fileName
        let trimmedFileName = decodedFileName.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedFileName.isEmpty ? nil : trimmedFileName
    }

    static func thumbnailSourcePaths(for asset: EnvironmentAsset) -> [String] {
        var paths: [String] = []
        appendThumbnailSource(asset.previewImagePath, to: &paths)
        appendThumbnailSource(asset.thumbnailPath, to: &paths)
        if isHDRIAsset(assetPath: asset.assetPath) {
            appendThumbnailSource(asset.assetPath, to: &paths)
        }
        return paths
    }

    static func thumbnailLoadID(for asset: EnvironmentAsset) -> String {
        let sources = thumbnailSourcePaths(for: asset)
        if sources.isEmpty {
            return asset.assetPath.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return sources.joined(separator: "\u{1F}")
    }

    private static func appendThumbnailSource(_ value: String?, to paths: inout [String]) {
        guard let path = value?.trimmingCharacters(in: .whitespacesAndNewlines),
              !path.isEmpty,
              !paths.contains(path) else {
            return
        }
        paths.append(path)
    }

    static func isReadableThumbnailFile(_ url: URL, fileManager: FileManager = .default) -> Bool {
        guard url.isFileURL,
              let values = try? url.resourceValues(forKeys: [
                .isRegularFileKey,
                .isSymbolicLinkKey,
                .isDirectoryKey,
              ]) else {
            return false
        }

        return values.isRegularFile == true
            && values.isSymbolicLink != true
            && values.isDirectory != true
            && fileManager.fileExists(atPath: url.path)
    }

    static func shouldClearActiveSelection(
        deleting assetID: String,
        selectedAssetID: String?,
        assets: [EnvironmentAsset]
    ) -> Bool {
        let normalizedAssetID = assetID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedAssetID.isEmpty else { return false }

        if selectedAssetID?.trimmingCharacters(in: .whitespacesAndNewlines) == normalizedAssetID {
            return true
        }

        return assets.contains { asset in
            asset.id == normalizedAssetID && asset.isActive
        }
    }

    private static func hasSelectedAssetID(_ id: String?) -> Bool {
        normalizedID(id).isEmpty == false
    }

    private static func normalizedID(_ id: String?) -> String {
        id?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }
}

#if os(visionOS)

private struct EnvironmentPreviewFallbackArtworkView: View {
    let kind: EnvironmentPreviewFallbackArtworkKind
    let paletteIndex: Int

    var body: some View {
        ZStack {
            LinearGradient(
                colors: palette,
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            GeometryReader { proxy in
                ZStack {
                    spotlight(size: proxy.size)
                    if showsHorizonGuide {
                        horizon(size: proxy.size)
                    }
                    accentGlyph(size: proxy.size)
                    foregroundIcon(size: proxy.size)
                }
                .frame(width: proxy.size.width, height: proxy.size.height)
            }
        }
        .clipped()
    }

    private var palette: [Color] {
        palettes[normalizedPaletteIndex]
    }

    private var accent: Color {
        switch kind {
        case .standardRoom:
            return Color(red: 0.82, green: 0.77, blue: 0.66)
        case .cinema:
            return Color(red: 1.00, green: 0.58, blue: 0.38)
        case .bundledEnvironment:
            return Color(red: 0.50, green: 0.90, blue: 0.92)
        case .panorama:
            return Color(red: 0.36, green: 0.84, blue: 0.74)
        case .scene:
            return Color(red: 0.92, green: 0.63, blue: 1.00)
        }
    }

    private var normalizedPaletteIndex: Int {
        guard !palettes.isEmpty else { return 0 }
        return max(0, paletteIndex) % palettes.count
    }

    private var showsHorizonGuide: Bool {
        kind == .bundledEnvironment || kind == .panorama
    }

    private var palettes: [[Color]] {
        switch kind {
        case .standardRoom:
            return [
                [Color(red: 0.04, green: 0.045, blue: 0.05), Color(red: 0.14, green: 0.15, blue: 0.15), Color(red: 0.24, green: 0.22, blue: 0.18)],
            ]
        case .cinema:
            return [
                [Color(red: 0.02, green: 0.02, blue: 0.03), Color(red: 0.24, green: 0.03, blue: 0.08), Color(red: 0.39, green: 0.24, blue: 0.08)],
            ]
        case .bundledEnvironment:
            return [
                [Color(red: 0.02, green: 0.11, blue: 0.22), Color(red: 0.06, green: 0.24, blue: 0.28), Color(red: 0.16, green: 0.11, blue: 0.34)],
                [Color(red: 0.11, green: 0.05, blue: 0.23), Color(red: 0.28, green: 0.10, blue: 0.28), Color(red: 0.05, green: 0.20, blue: 0.26)],
                [Color(red: 0.05, green: 0.13, blue: 0.16), Color(red: 0.13, green: 0.27, blue: 0.20), Color(red: 0.18, green: 0.13, blue: 0.34)],
                [Color(red: 0.15, green: 0.07, blue: 0.09), Color(red: 0.30, green: 0.16, blue: 0.10), Color(red: 0.07, green: 0.16, blue: 0.24)],
            ]
        case .panorama:
            return [
                [Color(red: 0.04, green: 0.13, blue: 0.25), Color(red: 0.05, green: 0.29, blue: 0.33), Color(red: 0.06, green: 0.15, blue: 0.34)],
                [Color(red: 0.11, green: 0.08, blue: 0.24), Color(red: 0.22, green: 0.12, blue: 0.34), Color(red: 0.05, green: 0.24, blue: 0.29)],
                [Color(red: 0.05, green: 0.18, blue: 0.17), Color(red: 0.12, green: 0.33, blue: 0.24), Color(red: 0.04, green: 0.13, blue: 0.27)],
                [Color(red: 0.18, green: 0.08, blue: 0.10), Color(red: 0.33, green: 0.18, blue: 0.12), Color(red: 0.07, green: 0.18, blue: 0.24)],
            ]
        case .scene:
            return [
                [Color(red: 0.12, green: 0.07, blue: 0.24), Color(red: 0.26, green: 0.09, blue: 0.31), Color(red: 0.12, green: 0.16, blue: 0.32)],
                [Color(red: 0.04, green: 0.12, blue: 0.22), Color(red: 0.10, green: 0.23, blue: 0.31), Color(red: 0.24, green: 0.13, blue: 0.25)],
                [Color(red: 0.16, green: 0.07, blue: 0.12), Color(red: 0.30, green: 0.16, blue: 0.12), Color(red: 0.12, green: 0.12, blue: 0.27)],
                [Color(red: 0.06, green: 0.15, blue: 0.12), Color(red: 0.15, green: 0.29, blue: 0.18), Color(red: 0.16, green: 0.10, blue: 0.27)],
            ]
        }
    }

    private func spotlight(size: CGSize) -> some View {
        Circle()
            .fill(accent.opacity(0.20))
            .frame(width: size.width * 0.82, height: size.width * 0.82)
            .blur(radius: 2)
            .offset(x: size.width * 0.26, y: -size.height * 0.46)
    }

    private func horizon(size: CGSize) -> some View {
        VStack(spacing: 8) {
            RoundedRectangle(cornerRadius: 4)
                .fill(.white.opacity(kind == .standardRoom ? 0.08 : 0.13))
                .frame(width: size.width * 0.68, height: 2)
            RoundedRectangle(cornerRadius: 18)
                .stroke(.white.opacity(0.09), lineWidth: 1)
                .frame(width: size.width * 0.76, height: size.height * 0.36)
        }
        .offset(y: size.height * 0.12)
    }

    private func accentGlyph(size: CGSize) -> some View {
        switch kind {
        case .cinema:
            return AnyView(
                HStack(spacing: size.width * 0.34) {
                    Capsule()
                        .fill(accent.opacity(0.16))
                        .frame(width: size.width * 0.10, height: size.height * 0.78)
                        .rotationEffect(.degrees(-18))
                    Capsule()
                        .fill(accent.opacity(0.16))
                        .frame(width: size.width * 0.10, height: size.height * 0.78)
                        .rotationEffect(.degrees(18))
                }
                .offset(y: -size.height * 0.04)
            )
        case .standardRoom:
            return AnyView(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(.white.opacity(0.14), style: StrokeStyle(lineWidth: 2, dash: [8, 7]))
                    .frame(width: size.width * 0.24, height: size.height * 0.34)
                    .offset(y: -size.height * 0.04)
            )
        case .bundledEnvironment:
            return AnyView(
                Image(systemName: "sparkle")
                    .font(.system(size: 82, weight: .bold))
                    .foregroundStyle(accent.opacity(0.16))
                    .offset(x: size.width * 0.20, y: -size.height * 0.18)
            )
        case .panorama:
            return AnyView(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(accent.opacity(0.20), lineWidth: 2)
                    .frame(width: size.width * 0.44, height: size.height * 0.30)
                    .offset(y: -size.height * 0.05)
            )
        case .scene:
            return AnyView(
                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .fill(accent.opacity(0.15))
                    .frame(width: size.width * 0.48, height: size.height * 0.18)
                    .rotationEffect(.degrees(-10))
                    .offset(y: size.height * 0.12)
            )
        }
    }

    private func foregroundIcon(size: CGSize) -> some View {
        Image(systemName: kind.iconName)
            .font(.system(size: 54, weight: .semibold))
            .symbolRenderingMode(.hierarchical)
            .foregroundStyle(.white.opacity(kind.iconOpacity))
            .shadow(color: .black.opacity(0.32), radius: 2, y: 1)
            .position(x: size.width * 0.58, y: size.height * 0.48)
    }
}

struct CinemaEnvironmentPreviewCard: View {
    let status: EnvironmentPreviewCardStatus
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            ZStack(alignment: .bottomLeading) {
                EnvironmentPreviewFallbackArtworkView(kind: .cinema, paletteIndex: 0)
                .frame(width: EnvironmentPreviewLayoutPolicy.cardWidth, height: EnvironmentPreviewLayoutPolicy.cardHeight)
                .clipShape(EnvironmentPreviewLayoutPolicy.cardShape)

                LinearGradient(
                    stops: [
                        .init(color: .clear, location: 0.0),
                        .init(color: .black.opacity(0.22), location: 0.36),
                        .init(color: .black.opacity(0.62), location: 0.64),
                        .init(color: .black.opacity(0.88), location: 1.0),
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .clipShape(EnvironmentPreviewLayoutPolicy.cardShape)

                VStack(alignment: .leading, spacing: 5) {
                    EnvironmentPreviewCardTitleText("Cinema Environment")
                    HStack(spacing: 5) {
                        Image(systemName: "theatermasks")
                            .font(.caption2)
                            .foregroundStyle(.white.opacity(0.86))
                        Text("Built-in")
                            .font(.caption2)
                            .foregroundStyle(.white.opacity(0.86))
                    }
                }
                .padding(16)
                .shadow(color: .black.opacity(0.55), radius: 2, y: 1)
            }
            .frame(width: EnvironmentPreviewLayoutPolicy.cardWidth, height: EnvironmentPreviewLayoutPolicy.cardHeight)
        }
        .buttonStyle(.plain)
        .overlay {
            EnvironmentPreviewLayoutPolicy.cardShape
                .strokeBorder(
                    LinearGradient(
                        colors: status.borderGradientColors,
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: status.isHighlighted ? 2.5 : 1
                )
        }
        .overlay(alignment: .topTrailing) {
            if let chip = status.chip {
                EnvironmentStatusChip(
                    title: chip.title,
                    systemImage: chip.systemImage,
                    tint: chip.tint
                )
                .padding(10)
            }
        }
        .shadow(color: .black.opacity(0.16), radius: 18, y: 6)
        .hoverEffect(.lift)
    }
}

struct NoEnvironmentPreviewCard: View {
    let status: EnvironmentPreviewCardStatus
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            ZStack(alignment: .bottomLeading) {
                EnvironmentPreviewFallbackArtworkView(kind: .standardRoom, paletteIndex: 0)
                .frame(width: EnvironmentPreviewLayoutPolicy.cardWidth, height: EnvironmentPreviewLayoutPolicy.cardHeight)
                .clipShape(EnvironmentPreviewLayoutPolicy.cardShape)

                LinearGradient(
                    stops: [
                        .init(color: .clear, location: 0.0),
                        .init(color: .black.opacity(0.20), location: 0.34),
                        .init(color: .black.opacity(0.58), location: 0.62),
                        .init(color: .black.opacity(0.84), location: 1.0),
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .clipShape(EnvironmentPreviewLayoutPolicy.cardShape)

                VStack(alignment: .leading, spacing: 5) {
                    EnvironmentPreviewCardTitleText(EnvironmentPreviewRowPolicy.appleEnvironmentTitle)
                    HStack(spacing: 5) {
                        Image(systemName: EnvironmentPreviewFallbackArtworkKind.standardRoom.iconName)
                            .font(.caption2)
                            .foregroundStyle(.white.opacity(0.86))
                        Text(EnvironmentPreviewRowPolicy.appleEnvironmentTypeLabel)
                            .font(.caption2)
                            .foregroundStyle(.white.opacity(0.86))
                    }
                }
                .padding(16)
                .shadow(color: .black.opacity(0.55), radius: 2, y: 1)
            }
            .frame(width: EnvironmentPreviewLayoutPolicy.cardWidth, height: EnvironmentPreviewLayoutPolicy.cardHeight)
        }
        .buttonStyle(.plain)
        .overlay {
            EnvironmentPreviewLayoutPolicy.cardShape
                .strokeBorder(
                    LinearGradient(
                        colors: status.borderGradientColors,
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: status.isHighlighted ? 2.5 : 1
                )
        }
        .overlay(alignment: .topTrailing) {
            if let chip = status.chip {
                EnvironmentStatusChip(title: chip.title, systemImage: chip.systemImage, tint: chip.tint)
                    .padding(10)
            }
        }
        .shadow(color: .black.opacity(0.16), radius: 18, y: 6)
        .hoverEffect(.lift)
    }
}

private struct EnvironmentStatusChip: View {
    let title: String
    let systemImage: String
    let tint: Color

    var body: some View {
        Label(title, systemImage: systemImage)
            .font(.caption2.weight(.bold))
            .labelStyle(.titleAndIcon)
            .foregroundStyle(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background {
                ZStack {
                    Capsule().fill(.regularMaterial)
                    Capsule().fill(tint.opacity(0.18))
                }
            }
            .overlay {
                Capsule()
                    .strokeBorder(tint.opacity(0.75), lineWidth: 1)
            }
    }
}

private struct EnvironmentPreviewCardTitleText: View {
    let title: String

    init(_ title: String) {
        self.title = title
    }

    var body: some View {
        Text(title)
            .font(.subheadline)
            .fontWeight(.semibold)
            .foregroundStyle(.white)
            .lineLimit(2)
            .minimumScaleFactor(0.82)
            .allowsTightening(true)
            .fixedSize(horizontal: false, vertical: true)
    }
}
#endif
