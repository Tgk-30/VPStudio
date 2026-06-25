#if os(visionOS)
import SwiftUI
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
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                header
                environmentGrid

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
            .padding(28)
        }
        .background {
            VPMenuBackground()
                .ignoresSafeArea()
        }
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

    private var header: some View {
        HStack(alignment: .top, spacing: 18) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Environments")
                    .font(.largeTitle.weight(.bold))
                    .foregroundStyle(.primary)

                Text("Choose an immersive environment to preview. The active environment opens automatically when playback starts.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 16)

            HStack(spacing: 10) {
                Button {
                    isShowingFileImporter = true
                } label: {
                    importButtonLabel
                }
                .buttonStyle(.borderedProminent)
                .disabled(isImportingEnvironment)

                Button("Done") { dismiss() }
                    .buttonStyle(.bordered)
            }
        }
    }

    private var environmentGrid: some View {
        let columns = [
            GridItem(.adaptive(minimum: 286, maximum: 340), spacing: 18),
        ]
        let selectedAssetID = EnvironmentPreviewRowPolicy.effectiveSelectedAssetID(
            appStateSelectedID: appState.selectedEnvironmentAsset?.id,
            assets: environments
        )
        return LazyVGrid(columns: columns, spacing: 18) {
            NoEnvironmentPreviewCard(
                status: EnvironmentPreviewRowPolicy.standardRoomStatus(
                    selectedAssetID: selectedAssetID,
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

    private var importPrompt: some View {
        HStack(spacing: 16) {
            Image(systemName: "mountain.2")
                .font(.system(size: 30, weight: .semibold))
                .foregroundStyle(.secondary)
                .frame(width: 44, height: 44)

            VStack(alignment: .leading, spacing: 4) {
                Text("No imported environments")
                    .font(.headline)
                Text("Import \(EnvironmentImportValidationPolicy.supportedExtensionDisplayList) files to build a reusable playback room library.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
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
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(.white.opacity(0.10), lineWidth: 1)
        }
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
                        .font(.headline)
                    Text("One-click import curated Poly Haven HDRI panoramas, then tap the card above to open them.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                ForEach(onlinePresets) { preset in
                    onlinePresetRow(preset)
                }
            }
        }
    }

    @ViewBuilder
    private func onlinePresetRow(_ preset: CuratedEnvironmentPreset) -> some View {
        let isInstalled = isPresetInstalled(preset)
        let isInstalling = installingPresetIDs.contains(preset.id)

        HStack(alignment: .center, spacing: 14) {
            Image(systemName: EnvironmentPreviewRowPolicy.providerIconName(for: preset.provider))
                .font(.title3)
                .frame(width: 34, height: 34)
                .foregroundStyle(.secondary)
                .background(.white.opacity(0.06), in: Circle())

            VStack(alignment: .leading, spacing: 3) {
                Text(preset.name)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Text(preset.description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("\(preset.provider.displayName) • \(preset.licenseName)")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            .layoutPriority(1)

            Spacer(minLength: 12)

            if isInstalled {
                Label("Added", systemImage: "checkmark.circle.fill")
                    .font(.caption)
                    .foregroundStyle(.green)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                    .background(.green.opacity(0.12), in: Capsule())
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
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(.white.opacity(0.10), lineWidth: 1)
        }
    }

    private func importErrorBanner(_ message: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.yellow)
            Text(message)
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
            Button("Dismiss") { importError = nil }
                .font(.caption)
        }
        .padding(12)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 10))
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
        let latestEnvironments = (try? await appState.environmentCatalogManager.fetchAssets()) ?? []
        guard !Task.isCancelled else { return }
        environments = latestEnvironments
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
                importError = error.localizedDescription
            }

        case .failure(let error):
            importError = error.localizedDescription
        }
    }

    private func isDeletingAsset(_ asset: EnvironmentAsset) -> Bool {
        deletingAssetIDs.contains(normalizedAssetID(asset.id))
    }

    private func normalizedAssetID(_ id: String) -> String {
        id.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func isPresetInstalled(_ preset: CuratedEnvironmentPreset) -> Bool {
        environments.contains { environment in
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
            importError = "Failed to delete: \(error.localizedDescription)"
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
            _ = try await appState.environmentCatalogManager.importCuratedPreset(preset)
            await coalescedLoadEnvironments()
        } catch {
            importError = error.localizedDescription
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
    @State private var thumbnailImageAssetPath: String?
    @State private var thumbnailFailed = false
    @State private var thumbnailLoadTask: Task<Void, Never>?

    private let cardWidth: CGFloat = 286
    private let cardHeight: CGFloat = 168

    var body: some View {
        Button(action: onSelect) {
            ZStack(alignment: .bottomLeading) {
                previewBackground
                    .frame(width: cardWidth, height: cardHeight)
                    .clipShape(RoundedRectangle(cornerRadius: 16))

                LinearGradient(
                    stops: [
                        .init(color: .clear, location: 0.0),
                        .init(color: .black.opacity(0.45), location: 0.55),
                        .init(color: .black.opacity(0.82), location: 1.0),
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .clipShape(RoundedRectangle(cornerRadius: 16))

                VStack(alignment: .leading, spacing: 5) {
                    HStack(spacing: 5) {
                        Image(systemName: EnvironmentPreviewRowPolicy.assetTypeIconName(forAssetPath: asset.assetPath))
                            .font(.caption2)
                            .foregroundStyle(.white.opacity(0.75))
                        Text(EnvironmentPreviewRowPolicy.assetTypeLabel(
                            sourceType: asset.sourceType,
                            assetPath: asset.assetPath
                        ))
                            .font(.caption2)
                            .foregroundStyle(.white.opacity(0.75))
                    }
                    Text(asset.name)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(.white)
                        .lineLimit(1)
                }
                .padding(16)
            }
            .frame(width: cardWidth, height: cardHeight)
        }
        .buttonStyle(.plain)
        .disabled(isDeleting)
        .overlay {
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(
                    LinearGradient(
                        colors: [activeBorderTop, activeBorderBottom],
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
                    systemImage: "hourglass"
                )
                .padding(10)
                .transition(.scale(0.7).combined(with: .opacity))
            } else if let chip = status.chip {
                EnvironmentStatusChip(
                    title: chip.title,
                    systemImage: chip.systemImage
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
            } else if thumbnailFailed && EnvironmentPreviewRowPolicy.isHDRIAsset(assetPath: asset.assetPath) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundStyle(.yellow)
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
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: status)
        .animation(.easeInOut(duration: 0.18), value: isDeleting)
        .hoverEffect(.lift)
        .task(id: asset.assetPath) {
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

    @ViewBuilder
    private var previewBackground: some View {
        if let image = thumbnailImage {
            Image(image, scale: 1.0, label: Text(asset.name))
                .resizable()
                .aspectRatio(contentMode: .fill)
        } else {
            placeholderGradient
        }
    }

    private var placeholderGradient: some View {
        let isHDRI = EnvironmentPreviewRowPolicy.isHDRIAsset(assetPath: asset.assetPath)
        return LinearGradient(
            colors: isHDRI
                ? [Color(red: 0.04, green: 0.07, blue: 0.18), Color(red: 0.08, green: 0.18, blue: 0.38)]
                : [Color(red: 0.06, green: 0.05, blue: 0.12), Color(red: 0.14, green: 0.10, blue: 0.26)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .overlay {
            Image(systemName: isHDRI ? "pano.fill" : "cube.transparent.fill")
                .font(.system(size: 48, weight: .semibold))
                .foregroundStyle(.white.opacity(0.20))
        }
    }

    // MARK: Helpers

    private var activeBorderTop: Color {
        status.isHighlighted ? VPColor.accent.opacity(0.95) : .white.opacity(0.18)
    }

    private var activeBorderBottom: Color {
        status.isHighlighted ? VPColor.accent.opacity(0.5) : .white.opacity(0.04)
    }

    // MARK: Thumbnail

    private func loadThumbnail() async {
        thumbnailFailed = false
        let paths = EnvironmentPreviewRowPolicy.thumbnailSourcePaths(for: asset)
        guard !paths.isEmpty else {
            thumbnailImage = nil
            thumbnailImageAssetPath = nil
            return
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
                      FileManager.default.fileExists(atPath: url.path) else {
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
            thumbnailImageAssetPath = asset.assetPath
        } else {
            if thumbnailImageAssetPath != asset.assetPath {
                thumbnailImage = nil
                thumbnailImageAssetPath = nil
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

enum EnvironmentPreviewCardStatus: Equatable, Sendable {
    case inactive
    case current
    case selected
    case active

    var isHighlighted: Bool {
        self != .inactive
    }

    var chip: (title: String, systemImage: String)? {
        switch self {
        case .inactive:
            return nil
        case .current:
            return ("Current", "checkmark.circle.fill")
        case .selected:
            return ("Selected", "checkmark")
        case .active:
            return ("Active", "checkmark.circle.fill")
        }
    }
}

enum EnvironmentPreviewRowPolicy {
    static func shouldShowImportPrompt(environments: [EnvironmentAsset]) -> Bool {
        !environments.contains { $0.sourceType == .imported }
    }

    static func effectiveSelectedAssetID(
        appStateSelectedID: String?,
        assets: [EnvironmentAsset]
    ) -> String? {
        let appStateID = normalizedID(appStateSelectedID)
        if !appStateID.isEmpty {
            return appStateID
        }

        return assets.first { asset in
            asset.isActive && !normalizedID(asset.id).isEmpty
        }.map(\.id)
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
        isImmersiveSpaceOpen: Bool
    ) -> EnvironmentPreviewCardStatus {
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
        if let previewImagePath = asset.previewImagePath?.trimmingCharacters(in: .whitespacesAndNewlines),
           !previewImagePath.isEmpty {
            paths.append(previewImagePath)
        }
        if isHDRIAsset(assetPath: asset.assetPath) {
            paths.append(asset.assetPath)
        }
        return paths
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

struct CinemaEnvironmentPreviewCard: View {
    let status: EnvironmentPreviewCardStatus
    let onSelect: () -> Void

    private let cardWidth: CGFloat = 286
    private let cardHeight: CGFloat = 168

    var body: some View {
        Button(action: onSelect) {
            ZStack(alignment: .bottomLeading) {
                LinearGradient(
                    colors: [
                        Color(red: 0.02, green: 0.02, blue: 0.03),
                        Color(red: 0.16, green: 0.02, blue: 0.07),
                        Color(red: 0.28, green: 0.22, blue: 0.10),
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .overlay {
                    Image(systemName: "theatermasks.fill")
                        .font(.system(size: 52, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.22))
                }
                .frame(width: cardWidth, height: cardHeight)
                .clipShape(RoundedRectangle(cornerRadius: 16))

                LinearGradient(
                    stops: [
                        .init(color: .clear, location: 0.0),
                        .init(color: .black.opacity(0.45), location: 0.55),
                        .init(color: .black.opacity(0.82), location: 1.0),
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .clipShape(RoundedRectangle(cornerRadius: 16))

                VStack(alignment: .leading, spacing: 5) {
                    HStack(spacing: 5) {
                        Image(systemName: "theatermasks")
                            .font(.caption2)
                            .foregroundStyle(.white.opacity(0.75))
                        Text("Built-in")
                            .font(.caption2)
                            .foregroundStyle(.white.opacity(0.75))
                    }
                    Text("Cinema Environment")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(.white)
                        .lineLimit(1)
                }
                .padding(16)
            }
            .frame(width: cardWidth, height: cardHeight)
        }
        .buttonStyle(.plain)
        .overlay {
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(
                    LinearGradient(
                        colors: [
                            status.isHighlighted ? VPColor.accent.opacity(0.95) : .white.opacity(0.18),
                            status.isHighlighted ? VPColor.accent.opacity(0.5) : .white.opacity(0.04),
                        ],
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
                    systemImage: chip.systemImage
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

    private let cardWidth: CGFloat = 286
    private let cardHeight: CGFloat = 168

    var body: some View {
        Button(action: onSelect) {
            ZStack(alignment: .bottomLeading) {
                LinearGradient(
                    colors: [
                        Color(red: 0.04, green: 0.045, blue: 0.05),
                        Color(red: 0.12, green: 0.13, blue: 0.14),
                        Color(red: 0.20, green: 0.19, blue: 0.17),
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .overlay {
                    Image(systemName: "rectangle.dashed")
                        .font(.system(size: 52, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.22))
                }
                .frame(width: cardWidth, height: cardHeight)
                .clipShape(RoundedRectangle(cornerRadius: 16))

                LinearGradient(
                    stops: [
                        .init(color: .clear, location: 0.0),
                        .init(color: .black.opacity(0.38), location: 0.52),
                        .init(color: .black.opacity(0.78), location: 1.0),
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .clipShape(RoundedRectangle(cornerRadius: 16))

                VStack(alignment: .leading, spacing: 5) {
                    HStack(spacing: 5) {
                        Image(systemName: "rectangle.dashed")
                            .font(.caption2)
                            .foregroundStyle(.white.opacity(0.75))
                        Text("Default")
                            .font(.caption2)
                            .foregroundStyle(.white.opacity(0.75))
                    }
                    Text("Standard Room")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(.white)
                        .lineLimit(1)
                }
                .padding(16)
            }
            .frame(width: cardWidth, height: cardHeight)
        }
        .buttonStyle(.plain)
        .overlay {
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(
                    LinearGradient(
                        colors: [
                            status.isHighlighted ? VPColor.accent.opacity(0.95) : .white.opacity(0.18),
                            status.isHighlighted ? VPColor.accent.opacity(0.5) : .white.opacity(0.04),
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: status.isHighlighted ? 2.5 : 1
                )
        }
        .overlay(alignment: .topTrailing) {
            if let chip = status.chip {
                EnvironmentStatusChip(title: chip.title, systemImage: chip.systemImage)
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
                    Capsule().fill(VPColor.accent.opacity(0.18))
                }
            }
            .overlay {
                Capsule()
                    .strokeBorder(VPColor.accent.opacity(0.75), lineWidth: 1)
            }
    }
}
#endif
