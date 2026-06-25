import SwiftUI
import os

enum LibraryLayoutPolicy {
    static let rootPinsContentToTop = true
    static let emptyStatePinsContentToTop = true
    static let emptyStateTopPadding: CGFloat = 20
    static let topTabMaxWidth: CGFloat = 720

    static func showsEmptyState(for selectedList: UserLibraryEntry.ListType, entryCount: Int, historyCount: Int) -> Bool {
        switch selectedList {
        case .history:
            return historyCount == 0
        default:
            return entryCount == 0
        }
    }
}

private let libraryImportLogger = Logger(subsystem: "com.vpstudio", category: "library-import")

enum LibraryFolderCreationPolicy {
    static let keyboardDismissDelayMilliseconds: UInt64 = 80

    static func normalizedName(_ input: String) -> String? {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}

enum LibraryFolderSelectionPolicy {
    static func selectedManualFolder(
        from folders: [LibraryFolder],
        selectedFolderID: String?
    ) -> LibraryFolder? {
        guard let selectedFolderID else { return nil }
        return folders.first(where: { $0.id == selectedFolderID && $0.isSystem == false })
    }

    static func selectedFolderIDAfterReload(
        loadedFolders: [LibraryFolder],
        currentSelection: String?
    ) -> String? {
        guard let currentSelection else { return nil }
        return loadedFolders.contains(where: { $0.id == currentSelection }) ? currentSelection : nil
    }

    static func manualFolderOrderIDs(afterReloading loadedFolders: [LibraryFolder]) -> [String] {
        loadedFolders.filter { !$0.isSystem }.map(\.id)
    }

    static func orderedUserFolders(
        _ userFolders: [LibraryFolder],
        manualFolderOrderIDs: [String]
    ) -> [LibraryFolder] {
        guard !manualFolderOrderIDs.isEmpty else { return userFolders }
        let byID = Dictionary(uniqueKeysWithValues: userFolders.map { ($0.id, $0) })
        var ordered = manualFolderOrderIDs.compactMap { byID[$0] }
        if ordered.count < userFolders.count {
            let included = Set(ordered.map(\.id))
            ordered.append(contentsOf: userFolders.filter { !included.contains($0.id) })
        }
        return ordered
    }
}

enum LibrarySelectionTransitionPolicy {
    static func shouldResetTransientFolderState(
        previous: UserLibraryEntry.ListType,
        next: UserLibraryEntry.ListType
    ) -> Bool {
        previous != next
    }
}

enum LibraryLoadingSurfacePolicy {
    static let title = "Loading Library"
    static let message = "Fetching watchlist, favorites, and history."

    static func shouldShowLoadingSurface(isLoadingSelection: Bool) -> Bool {
        isLoadingSelection
    }
}

enum LibraryActionFailurePolicy {
    enum Action: Equatable {
        case createFolder
        case moveTitle
        case removeTitle(listName: String)
        case refreshTitles(listName: String)
        case reorderFolders
        case deleteFolder
    }

    static func appError(for error: Error, action: Action) -> AppError {
        AppError(error, fallback: .unknown(fallbackMessage(for: action)))
    }

    private static func fallbackMessage(for action: Action) -> String {
        switch action {
        case .createFolder:
            return "Couldn't create the folder."
        case .moveTitle:
            return "Couldn't move this title right now."
        case .removeTitle(let listName):
            return "Couldn't remove this title from \(listName)."
        case .refreshTitles(let listName):
            return "Couldn't refresh duplicate titles in \(listName)."
        case .reorderFolders:
            return "Couldn't save the new folder order."
        case .deleteFolder:
            return "Couldn't delete this folder."
        }
    }
}

enum LibraryFeedbackMessage: Equatable {
    case status(String)
    case error(AppError)
}

enum LibraryFeedbackPresentationPolicy {
    static func message(statusMessage: String?, actionError: AppError?) -> LibraryFeedbackMessage? {
        if let actionError {
            return .error(actionError)
        }

        guard let statusMessage, !statusMessage.isEmpty else { return nil }
        return .status(statusMessage)
    }
}

enum LibraryTitleRefreshPolicy {
    static func canStartRefresh(
        selectedList: UserLibraryEntry.ListType,
        isRefreshing: Bool
    ) -> Bool {
        selectedList != .history && !isRefreshing
    }

    static func refreshingMessage(for listType: UserLibraryEntry.ListType) -> String {
        "Refreshing title matches in \(listType.displayName)..."
    }

    static func completionMessage(
        for listType: UserLibraryEntry.ListType,
        removedCount: Int
    ) -> String {
        switch removedCount {
        case 0:
            return "Refresh complete: no duplicate titles found in \(listType.displayName)."
        case 1:
            return "Refresh complete: merged 1 duplicate title in \(listType.displayName)."
        default:
            return "Refresh complete: merged \(removedCount) duplicate titles in \(listType.displayName)."
        }
    }
}

enum LibraryHeaderActionKind: String, CaseIterable, Identifiable {
    case sort
    case export
    case `import`
    case refresh

    var id: String { rawValue }
}

struct LibraryHeaderActionSpec: Identifiable, Equatable {
    let kind: LibraryHeaderActionKind
    let title: String
    let systemImage: String
    let isEnabled: Bool

    var id: LibraryHeaderActionKind { kind }
}

enum LibraryActionRowPolicy {
    static func actions(
        selectedList: UserLibraryEntry.ListType,
        isRefreshing: Bool
    ) -> [LibraryHeaderActionSpec] {
        [
            LibraryHeaderActionSpec(
                kind: .sort,
                title: "Sort",
                systemImage: "arrow.up.arrow.down",
                isEnabled: true
            ),
            LibraryHeaderActionSpec(
                kind: .export,
                title: "Export",
                systemImage: "square.and.arrow.up",
                isEnabled: true
            ),
            LibraryHeaderActionSpec(
                kind: .import,
                title: "Import",
                systemImage: "square.and.arrow.down",
                isEnabled: true
            ),
            LibraryHeaderActionSpec(
                kind: .refresh,
                title: isRefreshing ? "Refreshing..." : "Refresh",
                systemImage: isRefreshing ? "hourglass" : "arrow.clockwise",
                isEnabled: LibraryTitleRefreshPolicy.canStartRefresh(
                    selectedList: selectedList,
                    isRefreshing: isRefreshing
                )
            ),
        ]
    }
}

enum LibraryFolderLabelPolicy {
    static let topLevelTitle = "Unsorted"
    private static let pathSeparator = " › "

    static func chipTitle(for folder: LibraryFolder, in allFolders: [LibraryFolder]) -> String {
        fullPath(for: folder, in: allFolders)
    }

    static func fullPath(for folder: LibraryFolder, in allFolders: [LibraryFolder]) -> String {
        guard !isSystemRoot(folder) else { return topLevelTitle }

        let segments = manualPathSegments(for: folder, in: allFolders)
        guard !segments.isEmpty else { return folder.name }
        return segments.joined(separator: pathSeparator)
    }

    private static func manualPathSegments(for folder: LibraryFolder, in allFolders: [LibraryFolder]) -> [String] {
        guard !isSystemRoot(folder) else { return [topLevelTitle] }

        let folderByID = Dictionary(uniqueKeysWithValues: allFolders.map { ($0.id, $0) })
        var segments = [folder.name]
        var visitedIDs: Set<String> = [folder.id]
        var currentParentID: String? = folder.parentId

        while let pid = currentParentID,
              let parent = folderByID[pid],
              !visitedIDs.contains(parent.id) {
            visitedIDs.insert(parent.id)

            if parent.isSystem || parent.folderKind == .systemRoot {
                break
            }

            segments.insert(parent.name, at: 0)
            currentParentID = parent.parentId
        }

        return segments
    }

    private static func isSystemRoot(_ folder: LibraryFolder) -> Bool {
        folder.isSystem && folder.folderKind == .systemRoot
    }
}

enum LibraryFolderReorderPolicy {
    static func reorderedIDs(
        orderedFolderIDs: [String],
        draggedFolderID: String?,
        destinationFolderID: String
    ) -> [String]? {
        guard let draggedFolderID,
              draggedFolderID != destinationFolderID,
              let fromIndex = orderedFolderIDs.firstIndex(of: draggedFolderID),
              let toIndex = orderedFolderIDs.firstIndex(of: destinationFolderID),
              fromIndex != toIndex else {
            return nil
        }

        var reorderedIDs = orderedFolderIDs
        reorderedIDs.move(
            fromOffsets: IndexSet(integer: fromIndex),
            toOffset: toIndex > fromIndex ? toIndex + 1 : toIndex
        )
        return reorderedIDs
    }

    static func shouldPersist(reorderedIDs: [String], currentIDs: [String]) -> Bool {
        reorderedIDs != currentIDs
    }
}

enum LibraryImportOutcomePolicy {
    static func displayedHistoryMediaIDs(from historyEntries: [WatchHistory]) -> [String] {
        var seen = Set<String>()
        var ordered: [String] = []
        for entry in historyEntries {
            if seen.insert(entry.mediaId).inserted {
                ordered.append(entry.mediaId)
            }
        }
        return ordered
    }

    static func preferredListType(after summary: LibraryCSVImportSummary) -> UserLibraryEntry.ListType? {
        if summary.watchlistImported > 0 { return .watchlist }
        if summary.favoritesImported > 0 { return .favorites }
        if summary.historyImported > 0 { return .history }
        return nil
    }

    static func importStatusMessage(from summary: LibraryCSVImportSummary) -> String {
        if summary.watchlistImported == 0, summary.favoritesImported == 0, summary.historyImported == 0 {
            if summary.ratingsImported > 0 {
                return "Import finished: no new library items, but \(summary.ratingsImported) ratings were imported."
            }
            return "Import finished: no new library items were added."
        }
        return "Import added W:\(summary.watchlistImported) F:\(summary.favoritesImported) H:\(summary.historyImported) from \(summary.rowsImported) rows. Repeated IMDb IDs across files were merged."
    }
}

enum LibraryMetadataHydrationPolicy {
    struct Candidate: Sendable, Hashable, Equatable {
        let requestedID: String
        let detailID: String
        let type: MediaType
    }

    static func candidates(
        for ids: [String],
        mediaItems: [String: MediaItem]
    ) -> [Candidate] {
        var seen = Set<String>()

        return ids.compactMap { requestedID in
            guard seen.insert(requestedID).inserted else { return nil }
            guard let item = mediaItems[requestedID] else { return nil }
            guard !item.hasArtwork else { return nil }

            if let imdbID = IMDbIdentifierPolicy.firstID(in: item.id) {
                return Candidate(
                    requestedID: requestedID,
                    detailID: imdbID,
                    type: item.type
                )
            }

            if let imdbID = IMDbIdentifierPolicy.firstID(in: requestedID) {
                return Candidate(
                    requestedID: requestedID,
                    detailID: imdbID,
                    type: item.type
                )
            }

            let title = item.title.trimmingCharacters(in: .whitespacesAndNewlines)
            if !title.isEmpty {
                return Candidate(
                    requestedID: requestedID,
                    detailID: title,
                    type: item.type
                )
            }

            return nil
        }
    }
}

struct LibraryView: View {
    @Environment(AppState.self) private var appState

    @State private var selectedList: UserLibraryEntry.ListType = .watchlist
    @State private var selectedFolderID: String?

    @State private var entries: [UserLibraryEntry] = []
    @State private var historyEntries: [WatchHistory] = []
    @State private var folders: [LibraryFolder] = []
    @State private var mediaItems: [String: MediaItem] = [:]

    /// Pushed detail for the Library tab, hoisted to AppState so it survives the player
    /// dismissing/re-opening the main window (see `AppState.libraryDetailSelection`).
    private var librarySelection: Binding<MediaPreview?> {
        Binding(get: { appState.libraryDetailSelection }, set: { appState.libraryDetailSelection = $0 })
    }
    @State private var loadTask: Task<Void, Never>?
    @State private var metadataHydrationTask: Task<Void, Never>?
    @State private var userRatingsReloadTask: Task<Void, Never>?
    @State private var didApplyQALibrarySelection = false

    @State private var sortOption: LibrarySortOption = .dateAddedDesc
    @State private var userRatings: [String: TasteEvent] = [:]

    @State private var isShowingCreateFolderSheet = false
    @State private var isShowingCSVImportSheet = false
    @State private var isShowingCSVExportSheet = false
    @State private var createFolderListType: UserLibraryEntry.ListType = .watchlist
    @State private var folderPendingDeletion: LibraryFolder?
    @State private var statusMessage: String?
    @State private var actionError: AppError?
    @State private var isRefreshingTitleDuplicates = false
    @State private var draggedFolderID: String?
    @State private var manualFolderOrderIDs: [String] = []
    @State private var isLoadingSelection = true
    @State private var selectionLoadToken = 0
    @AppStorage(VPDesignFlags.useObsidianGlassKey) private var useObsidianGlass = true

    private let disablesAutomaticTasks: Bool
    private let initialCreateFolderName: String
    private let initialCreateFolderErrorMessage: String?
    private let initialCreateFolderIsSubmitting: Bool
    private let autoFocusesCreateFolderNameField: Bool

    init(
        initialSelectedList: UserLibraryEntry.ListType = .watchlist,
        initialSelectedFolderID: String? = nil,
        initialEntries: [UserLibraryEntry] = [],
        initialHistoryEntries: [WatchHistory] = [],
        initialFolders: [LibraryFolder] = [],
        initialMediaItems: [String: MediaItem] = [:],
        initialSortOption: LibrarySortOption = .dateAddedDesc,
        initialUserRatings: [String: TasteEvent] = [:],
        initialIsShowingCreateFolderSheet: Bool = false,
        initialIsShowingCSVImportSheet: Bool = false,
        initialIsShowingCSVExportSheet: Bool = false,
        initialCreateFolderListType: UserLibraryEntry.ListType = .watchlist,
        initialFolderPendingDeletion: LibraryFolder? = nil,
        initialStatusMessage: String? = nil,
        initialActionError: AppError? = nil,
        initialIsRefreshingTitleDuplicates: Bool = false,
        initialManualFolderOrderIDs: [String] = [],
        initialIsLoadingSelection: Bool = true,
        initialCreateFolderName: String = "",
        initialCreateFolderErrorMessage: String? = nil,
        initialCreateFolderIsSubmitting: Bool = false,
        autoFocusesCreateFolderNameField: Bool = true,
        disablesAutomaticTasks: Bool = false
    ) {
        _selectedList = State(initialValue: initialSelectedList)
        _selectedFolderID = State(initialValue: initialSelectedFolderID)
        _entries = State(initialValue: initialEntries)
        _historyEntries = State(initialValue: initialHistoryEntries)
        _folders = State(initialValue: initialFolders)
        _mediaItems = State(initialValue: initialMediaItems)
        _sortOption = State(initialValue: initialSortOption)
        _userRatings = State(initialValue: initialUserRatings)
        _isShowingCreateFolderSheet = State(initialValue: initialIsShowingCreateFolderSheet)
        _isShowingCSVImportSheet = State(initialValue: initialIsShowingCSVImportSheet)
        _isShowingCSVExportSheet = State(initialValue: initialIsShowingCSVExportSheet)
        _createFolderListType = State(initialValue: initialCreateFolderListType)
        _folderPendingDeletion = State(initialValue: initialFolderPendingDeletion)
        _statusMessage = State(initialValue: initialStatusMessage)
        _actionError = State(initialValue: initialActionError)
        _isRefreshingTitleDuplicates = State(initialValue: initialIsRefreshingTitleDuplicates)
        _manualFolderOrderIDs = State(initialValue: initialManualFolderOrderIDs)
        _isLoadingSelection = State(initialValue: initialIsLoadingSelection)
        self.initialCreateFolderName = initialCreateFolderName
        self.initialCreateFolderErrorMessage = initialCreateFolderErrorMessage
        self.initialCreateFolderIsSubmitting = initialCreateFolderIsSubmitting
        self.autoFocusesCreateFolderNameField = autoFocusesCreateFolderNameField
        self.disablesAutomaticTasks = disablesAutomaticTasks
    }

    private var displayedHistoryMediaIDs: [String] {
        LibraryImportOutcomePolicy.displayedHistoryMediaIDs(from: historyEntries)
    }

    private var isEmptyStateVisible: Bool {
        LibraryLayoutPolicy.showsEmptyState(
            for: selectedList,
            entryCount: entries.count,
            historyCount: displayedHistoryMediaIDs.count
        )
    }

    private var titleCount: Int {
        selectedList == .history ? displayedHistoryMediaIDs.count : entries.count
    }

    private var allFolderOptions: [LibraryFolder] {
        folders.filter { $0.listType == selectedList }
    }

    private var userFolders: [LibraryFolder] {
        allFolderOptions.filter { !$0.isSystem }
    }

    private var orderedUserFolders: [LibraryFolder] {
        LibraryFolderSelectionPolicy.orderedUserFolders(
            userFolders,
            manualFolderOrderIDs: manualFolderOrderIDs
        )
    }

    private var rootFolder: LibraryFolder? {
        allFolderOptions.first { $0.isSystem && $0.folderKind == .systemRoot }
    }

    private typealias MetadataHydrationCandidate = LibraryMetadataHydrationPolicy.Candidate

    private var selectedManualFolder: LibraryFolder? {
        LibraryFolderSelectionPolicy.selectedManualFolder(
            from: allFolderOptions,
            selectedFolderID: selectedFolderID
        )
    }

    private var headerActions: [LibraryHeaderActionSpec] {
        LibraryActionRowPolicy.actions(
            selectedList: selectedList,
            isRefreshing: isRefreshingTitleDuplicates
        )
    }

    private var feedbackMessage: LibraryFeedbackMessage? {
        LibraryFeedbackPresentationPolicy.message(
            statusMessage: statusMessage,
            actionError: actionError
        )
    }

    var body: some View {
        VStack(spacing: 0) {
            header
                .frame(maxWidth: .infinity, alignment: .leading)

            if LibraryLoadingSurfacePolicy.shouldShowLoadingSurface(isLoadingSelection: isLoadingSelection) {
                VStack {
                    Spacer()
                    LoadingOverlay(
                        title: LibraryLoadingSurfacePolicy.title,
                        message: LibraryLoadingSurfacePolicy.message
                    )
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if isEmptyStateVisible {
                LibraryEmptyStateView(
                    listType: emptyStateCTAListType
                ) { action in
                    handleCTAAction(action)
                }
                .frame(
                    maxWidth: .infinity,
                    maxHeight: .infinity,
                    alignment: LibraryLayoutPolicy.emptyStatePinsContentToTop ? .top : .center
                )
                .padding(.top, LibraryLayoutPolicy.emptyStateTopPadding)
            } else {
                ScrollView {
                    LazyVGrid(
                        columns: [GridItem(
                            .adaptive(minimum: LibraryGridPolicy.cardMinWidth),
                            spacing: LibraryGridPolicy.gridSpacing
                        )],
                        spacing: LibraryGridPolicy.gridSpacing
                    ) {
                        if selectedList == .history {
                            ForEach(displayedHistoryMediaIDs, id: \.self) { mediaId in
                                if let preview = historyPreview(for: mediaId) {
                                    Button { appState.libraryDetailSelection = preview } label: {
                                        MediaCardView(item: preview, userRating: userRating(for: preview, storedMediaID: mediaId))
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        } else {
                            ForEach(entries, id: \.id) { entry in
                                if let preview = preview(for: entry.mediaId) {
                                    Button { appState.libraryDetailSelection = preview } label: {
                                        MediaCardView(item: preview, userRating: userRating(for: preview, storedMediaID: entry.mediaId))
                                    }
                                    .buttonStyle(.plain)
                                    .contextMenu {
                                        if selectedList.supportsFolders {
                                            ForEach(allFolderOptions, id: \.id) { folder in
                                                if folder.id != entry.folderId {
                                                    Button(
                                                        "Move to \(LibraryFolderLabelPolicy.fullPath(for: folder, in: allFolderOptions))"
                                                    ) {
                                                        move(entry: entry, to: folder)
                                                    }
                                                }
                                            }

                                            Divider()
                                        }

                                        Button(role: .destructive) {
                                            remove(entry: entry)
                                        } label: {
                                            Label("Remove from \(entry.listType.displayName)", systemImage: "trash")
                                        }
                                    }
                                }
                            }
                        }
                    }
                    .padding(.horizontal, LibraryGridPolicy.horizontalPadding)
                    .padding(.top, LibraryGridPolicy.topContentPadding)
                    .padding(.bottom, LibraryGridPolicy.bottomContentPadding)
                }
            }
        }
        .frame(
            maxWidth: .infinity,
            maxHeight: .infinity,
            alignment: LibraryLayoutPolicy.rootPinsContentToTop ? .top : .center
        )
        .background {
            if useObsidianGlass {
                VPBackground()
            } else {
                VPMenuBackground()
                    .ignoresSafeArea()
            }
        }
        .navigationTitle(useObsidianGlass ? "" : "Library")
        #if !os(macOS)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .navigationBar)
        #endif
        .navigationDestination(item: librarySelection) { item in
            DetailView(preview: item)
        }
        .sheet(isPresented: $isShowingCreateFolderSheet) {
            CreateLibraryFolderSheet(
                listType: createFolderListType,
                initialFolderName: initialCreateFolderName,
                initialErrorMessage: initialCreateFolderErrorMessage,
                initialIsSubmitting: initialCreateFolderIsSubmitting,
                autoFocusesNameField: autoFocusesCreateFolderNameField
            ) { name, listType in
                await createFolder(named: name, in: listType)
            }
        }
        .sheet(isPresented: $isShowingCSVImportSheet) {
            LibraryCSVImportSheet { summary in
                if let preferred = preferredListType(after: summary) {
                    selectedList = preferred
                }
                selectedFolderID = nil
                statusMessage = importStatusMessage(from: summary)
                let importStatus = statusMessage ?? ""
                libraryImportLogger.debug("visible-list=\(selectedList.rawValue, privacy: .public) status=\(importStatus, privacy: .public)")
                scheduleReload()
            }
        }
        .sheet(isPresented: $isShowingCSVExportSheet) {
            LibraryCSVExportSheet()
        }
        .confirmationDialog(
            "Delete Folder",
            isPresented: Binding(
                get: { folderPendingDeletion != nil },
                set: { isPresented in
                    if !isPresented { folderPendingDeletion = nil }
                }
            ),
            titleVisibility: .visible
        ) {
            if let folder = folderPendingDeletion {
                Button(
                    "Delete \"\(LibraryFolderLabelPolicy.fullPath(for: folder, in: allFolderOptions))\"",
                    role: .destructive
                ) {
                    let target = folder
                    folderPendingDeletion = nil
                    delete(folder: target)
                }
            }
            Button("Cancel", role: .cancel) {
                folderPendingDeletion = nil
            }
        } message: {
            if let folder = folderPendingDeletion {
                Text(
                    "Items in this folder will be moved to \(LibraryFolderLabelPolicy.topLevelTitle) in \(folder.listType.displayName)."
                )
            }
        }
        .task {
            guard !disablesAutomaticTasks else { return }
            if let qaList = QARuntimeOptions.libraryList, !didApplyQALibrarySelection {
                didApplyQALibrarySelection = true
                selectedList = qaList
            }
            scheduleReload()
        }
        .onDisappear {
            loadTask?.cancel()
            loadTask = nil
            metadataHydrationTask?.cancel()
            metadataHydrationTask = nil
            userRatingsReloadTask?.cancel()
            userRatingsReloadTask = nil
        }
        .onChange(of: selectedList) { previous, next in
            selectedFolderID = nil

            if LibrarySelectionTransitionPolicy.shouldResetTransientFolderState(previous: previous, next: next) {
                draggedFolderID = nil
                manualFolderOrderIDs = []
                mediaItems = [:]
            }

            guard !disablesAutomaticTasks else { return }
            scheduleReload()
        }
        .onChange(of: selectedFolderID) { _, _ in
            guard !disablesAutomaticTasks else { return }
            guard selectedList.supportsFolders else { return }
            scheduleReload()
        }
        .onChange(of: sortOption) { _, _ in
            guard !disablesAutomaticTasks else { return }
            scheduleReload()
        }
        .onReceive(NotificationCenter.default.publisher(for: .libraryDidChange)) { _ in
            guard !disablesAutomaticTasks else { return }
            scheduleReload()
        }
        .onReceive(NotificationCenter.default.publisher(for: .watchHistoryDidChange)) { _ in
            guard !disablesAutomaticTasks else { return }
            scheduleReload()
        }
        .task {
            guard !disablesAutomaticTasks else { return }
            await loadUserRatings()
        }
        .onReceive(NotificationCenter.default.publisher(for: .tasteProfileDidChange)) { _ in
            guard !disablesAutomaticTasks else { return }
            userRatingsReloadTask?.cancel()
            userRatingsReloadTask = Task { await loadUserRatings() }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .center, spacing: 14) {
                VStack(alignment: .leading, spacing: 4) {
                    // Stable title — the active list name already shows in the picker below,
                    // so mirroring it here printed e.g. "Watchlist" twice.
                    Text("My Library")
                        .font(.title3)
                        .fontWeight(.semibold)
                    GlassTag(text: "\(titleCount) titles", symbol: "film")
                }
                Spacer(minLength: 20)

                actionRow
            }

            GlassPillPicker(
                options: UserLibraryEntry.ListType.libraryTopTabs,
                selection: $selectedList
            )
            .frame(maxWidth: LibraryLayoutPolicy.topTabMaxWidth, alignment: .leading)

            if selectedList.supportsFolders {
                folderControls
            }

            if let feedbackMessage {
                switch feedbackMessage {
                case .status(let statusMessage):
                    Text(statusMessage)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                case .error(let error):
                    AppErrorInlineView(error: error)
                }
            }
        }
        .padding(.horizontal, LibraryGridPolicy.horizontalPadding)
        .padding(.top, 14)
        .padding(.bottom, 10)
    }

    private var actionRow: some View {
        HStack(spacing: 12) {
            // Sort stays a first-class capsule; the infrequent maintenance
            // actions (Export/Import/Refresh) collapse into a trailing overflow.
            sortMenu
            overflowMenu
        }
        .padding(.vertical, 2)
    }

    private var overflowMenu: some View {
        Menu {
            ForEach(headerActions.filter { $0.kind != .sort }) { action in
                overflowMenuItem(for: action)
            }
        } label: {
            actionCapsuleLabel(
                title: "More",
                systemImage: "ellipsis",
                tint: .secondary
            )
            .labelStyle(.iconOnly)
            .accessibilityLabel("More Library Actions")
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func overflowMenuItem(for action: LibraryHeaderActionSpec) -> some View {
        switch action.kind {
        case .sort:
            EmptyView()
        case .export:
            Button {
                isShowingCSVExportSheet = true
            } label: {
                Label(action.title, systemImage: action.systemImage)
            }
        case .import:
            Button {
                isShowingCSVImportSheet = true
            } label: {
                Label(action.title, systemImage: action.systemImage)
            }
        case .refresh:
            Button {
                refreshTitleDuplicates()
            } label: {
                Label(action.title, systemImage: action.systemImage)
            }
            .disabled(!action.isEnabled)
        }
    }

    private var folderControls: some View {
        HStack(spacing: 12) {
            Button {
                createFolderListType = selectedList
                isShowingCreateFolderSheet = true
            } label: {
                actionCapsuleLabel(
                    title: "New Folder",
                    systemImage: "folder.badge.plus",
                    tint: VPColor.accent
                )
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Create Folder")

            if let selectedManualFolder {
                Button(role: .destructive) {
                    folderPendingDeletion = selectedManualFolder
                } label: {
                    actionCapsuleLabel(
                        title: "Delete",
                        systemImage: "trash",
                        tint: .red
                    )
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Delete Selected Folder")
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    folderChip(title: "All", isSelected: selectedFolderID == nil) {
                        selectedFolderID = nil
                    }

                    if let rootFolder {
                        folderChip(
                            title: LibraryFolderLabelPolicy.chipTitle(for: rootFolder, in: allFolderOptions),
                            isSelected: selectedFolderID == rootFolder.id
                        ) {
                            selectedFolderID = rootFolder.id
                        }
                        .help("Items at the top level of \(selectedList.displayName)")
                    }

                    ForEach(orderedUserFolders, id: \.id) { folder in
                        folderChip(for: folder)
                            .onDrag {
                                draggedFolderID = folder.id
                                if manualFolderOrderIDs.isEmpty {
                                    manualFolderOrderIDs = userFolders.map(\.id)
                                }
                                return NSItemProvider(object: folder.id as NSString)
                            }
                            .onDrop(
                                of: ["public.text"],
                                delegate: FolderChipDropDelegate(
                                    destinationFolderID: folder.id,
                                    orderedFolderIDs: $manualFolderOrderIDs,
                                    draggedFolderID: $draggedFolderID
                                ) { reorderedIDs in
                                    commitFolderReorder(reorderedIDs)
                                }
                            )
                    }
                }
            }
        }
    }

    private var sortMenu: some View {
        Menu {
            Picker("Sort By", selection: $sortOption) {
                ForEach(LibrarySortOption.allCases, id: \.self) { option in
                    Label(option.displayName, systemImage: option.symbolName)
                        .tag(option)
                }
            }
        } label: {
            actionCapsuleLabel(
                title: "Sort",
                systemImage: "arrow.up.arrow.down",
                tint: .teal
            )
        }
        .buttonStyle(.plain)
    }

    private func actionCapsuleLabel(title: String, systemImage: String, tint: Color) -> some View {
        Label(title, systemImage: systemImage)
            .font(.subheadline.weight(.semibold))
            .labelStyle(.titleAndIcon)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .frame(minHeight: 44)
            .contentShape(Capsule())
            .background(.regularMaterial, in: Capsule())
            .overlay {
                ZStack {
                    Capsule()
                        .fill(tint.opacity(0.14))
                    Capsule()
                        .strokeBorder(Color.white.opacity(0.22), lineWidth: 1)
                }
            }
            .shadow(color: .black.opacity(0.08), radius: 14, y: 2)
    }

    private func folderChip(title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            if useObsidianGlass {
                Text(title)
                    .font(VPFont.label)
                    .lineLimit(1)
                    .foregroundStyle(isSelected ? VPColor.textPrimary : VPColor.textSecondary)
                    .padding(.horizontal, VPSpace.normal)
                    .frame(minHeight: VPSpace.minTapTarget)
                    // Selected state stays glass with an accent ring + glow — never an opaque red slab.
                    .glassSurface(isSelected ? .hero : .rest, cornerRadius: VPSpace.minTapTarget / 2)
                    .background {
                        if isSelected {
                            Capsule().fill(VPColor.accent.opacity(0.20))
                        }
                    }
                    .overlay {
                        if isSelected {
                            Capsule().strokeBorder(VPColor.accent, lineWidth: 2)
                        }
                    }
                    .shadow(color: isSelected ? VPColor.accentGlow : .clear, radius: 12)
            } else {
                Text(title)
                    .font(.caption.weight(.semibold))
                    .lineLimit(1)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                    .background(
                        isSelected ? AnyShapeStyle(Color.vpRed) : AnyShapeStyle(.ultraThinMaterial),
                        in: Capsule()
                    )
                    .overlay {
                        if !isSelected {
                            Capsule()
                                .strokeBorder(Color.white.opacity(0.16), lineWidth: 1)
                        }
                    }
                    .foregroundStyle(isSelected ? .white : .primary)
            }
        }
        .buttonStyle(.plain)
        .vpInteractive()
    }

    private func folderChip(for folder: LibraryFolder) -> some View {
        let folderLabel = LibraryFolderLabelPolicy.chipTitle(for: folder, in: allFolderOptions)

        return folderChip(title: folderLabel, isSelected: selectedFolderID == folder.id) {
            selectedFolderID = folder.id
        }
        .help(LibraryFolderLabelPolicy.fullPath(for: folder, in: allFolderOptions))
        .contextMenu {
            Button(role: .destructive) {
                folderPendingDeletion = folder
            } label: {
                Label("Delete \(folderLabel)", systemImage: "trash")
            }
        }
    }

    private var emptyStateCTAListType: LibraryEmptyStateCTAPolicy.ListType {
        switch selectedList {
        case .watchlist: return .watchlist
        case .favorites: return .favorites
        case .history: return .history
        }
    }

    private func handleCTAAction(_ action: LibraryEmptyStateCTAPolicy.CTAAction) {
        switch action {
        case .switchToDiscover:
            appState.selectedTab = .discover
        case .openSettings:
            appState.selectedTab = .settings
        case .none:
            break
        }
    }

    private func preferredListType(after summary: LibraryCSVImportSummary) -> UserLibraryEntry.ListType? {
        LibraryImportOutcomePolicy.preferredListType(after: summary)
    }

    private func importStatusMessage(from summary: LibraryCSVImportSummary) -> String {
        LibraryImportOutcomePolicy.importStatusMessage(from: summary)
    }

    private func scheduleReload() {
        loadTask?.cancel()
        metadataHydrationTask?.cancel()

        selectionLoadToken += 1
        let loadToken = selectionLoadToken
        isLoadingSelection = true

        loadTask = Task { await loadSelection(loadToken: loadToken) }
    }

    private func loadSelection(loadToken: Int? = nil) async {
        let resolvedLoadToken = loadToken ?? selectionLoadToken

        RuntimeMemoryDiagnostics.capture(
            event: .libraryLoadStarted,
            enabled: appState.runtimeDiagnosticsEnabled,
            context: selectedList.displayName
        )
        defer {
            if selectionLoadToken == resolvedLoadToken {
                isLoadingSelection = false
            }

            RuntimeMemoryDiagnostics.capture(
                event: .libraryLoadFinished,
                enabled: appState.runtimeDiagnosticsEnabled,
                context: "\(selectedList.displayName):entries=\(entries.count),history=\(displayedHistoryMediaIDs.count)"
            )
        }

        if selectedList == .history {
            await loadHistoryEntries(loadToken: resolvedLoadToken)
            guard selectionLoadToken == resolvedLoadToken else { return }
            scheduleMetadataHydration(for: displayedHistoryMediaIDs)
            return
        }

        await loadFolders(loadToken: resolvedLoadToken)
        guard selectionLoadToken == resolvedLoadToken else { return }
        await loadLibraryEntries(loadToken: resolvedLoadToken)
        guard selectionLoadToken == resolvedLoadToken else { return }
        scheduleMetadataHydration(for: entries.map(\.mediaId))
    }

    private func loadFolders(loadToken: Int) async {
        guard selectedList.supportsFolders else {
            guard selectionLoadToken == loadToken else { return }
            folders = []
            manualFolderOrderIDs = []
            return
        }

        let loadedFolders = (try? await appState.database.fetchAllLibraryFolders(listType: selectedList)) ?? []
        guard selectionLoadToken == loadToken else { return }
        folders = loadedFolders
        draggedFolderID = nil
        manualFolderOrderIDs = LibraryFolderSelectionPolicy.manualFolderOrderIDs(afterReloading: loadedFolders)
        selectedFolderID = LibraryFolderSelectionPolicy.selectedFolderIDAfterReload(
            loadedFolders: loadedFolders,
            currentSelection: selectedFolderID
        )
    }

    private func loadLibraryEntries(loadToken: Int) async {
        let loadedEntries = (try? await appState.database.fetchLibraryEntries(
            listType: selectedList,
            folderId: selectedFolderID,
            sortOption: sortOption
        )) ?? []
        await loadMediaItemsIfMissing(ids: loadedEntries.map(\.mediaId), loadToken: loadToken)
        guard selectionLoadToken == loadToken else { return }
        entries = loadedEntries
        historyEntries = []
    }

    private func loadHistoryEntries(loadToken: Int) async {
        guard selectedList == .history else { return }
        let loadedHistory = (try? await appState.database.fetchWatchHistory(limit: 200)) ?? []
        await loadMediaItemsIfMissing(ids: loadedHistory.map(\.mediaId), loadToken: loadToken)
        guard selectionLoadToken == loadToken else { return }
        selectedFolderID = nil
        draggedFolderID = nil
        manualFolderOrderIDs = []
        folders = []
        entries = []
        historyEntries = loadedHistory
    }

    private func loadMediaItemsIfMissing(ids: [String], loadToken: Int) async {
        var seen = Set<String>()
        let uniqueIDs = ids.filter { seen.insert($0).inserted }

        let missingIDs = uniqueIDs.filter { mediaItems[$0] == nil }
        guard !missingIDs.isEmpty else { return }

        let fetchedItems = (try? await appState.database.fetchMediaItemsResolvingAliases(ids: missingIDs)) ?? [:]
        guard selectionLoadToken == loadToken else { return }
        for requestedID in missingIDs {
            guard let item = fetchedItems[requestedID] else { continue }
            mediaItems[requestedID] = item
        }
    }

    @MainActor
    private func loadUserRatings() async {
        let events = (try? await appState.database.fetchTasteEvents(eventType: .rated, limit: 500)) ?? []
        guard !Task.isCancelled else { return }
        userRatings = TasteRatingLookupPolicy.lookup(from: events)
    }

    private func userRating(for preview: MediaPreview, storedMediaID: String) -> TasteEvent? {
        TasteRatingLookupPolicy.rating(
            in: userRatings,
            mediaId: storedMediaID,
            type: preview.type,
            tmdbId: preview.tmdbId,
            resolvedMediaId: mediaItems[storedMediaID]?.id ?? preview.id
        )
    }

    private func preview(for mediaID: String) -> MediaPreview? {
        if let item = mediaItems[mediaID] {
            return MediaPreview(
                id: mediaID,
                type: item.type,
                title: item.title,
                year: item.year,
                posterPath: item.posterPath,
                backdropPath: item.backdropPath,
                imdbRating: item.imdbRating,
                tmdbId: item.tmdbId
            )
        }
        return nil
    }

    private func historyPreview(for mediaID: String) -> MediaPreview? {
        if let preview = preview(for: mediaID) {
            return preview
        }

        guard let historyEntry = historyEntries.first(where: { $0.mediaId == mediaID }) else {
            return nil
        }

        return MediaPreview(
            id: historyEntry.mediaId,
            type: historyEntry.episodeId == nil ? .movie : .series,
            title: historyEntry.title,
            year: nil,
            posterPath: nil,
            imdbRating: nil,
            tmdbId: nil,
            episodeId: historyEntry.episodeId
        )
    }

    private func scheduleMetadataHydration(for ids: [String]) {
        metadataHydrationTask?.cancel()

        let candidates = Array(metadataHydrationCandidates(for: ids).prefix(24))
        guard !candidates.isEmpty else {
            metadataHydrationTask = nil
            return
        }

        metadataHydrationTask = Task {
            let apiKey = (try? await appState.settingsManager.getMetadataApiKey()) ?? ""
            let normalizedAPIKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !normalizedAPIKey.isEmpty else {
                await MainActor.run {
                    metadataHydrationTask = nil
                }
                return
            }

            let metadataService = appState.createMetadataService(apiKey: normalizedAPIKey)

            for candidate in candidates {
                guard !Task.isCancelled else { break }
                guard let hydrated = try? await metadataService.getDetail(id: candidate.detailID, type: candidate.type) else {
                    continue
                }

                let cached = hydrated.withID(candidate.requestedID)
                try? await appState.database.saveMediaItem(cached)

                await MainActor.run {
                    mediaItems[candidate.requestedID] = cached
                }
            }

            await MainActor.run {
                metadataHydrationTask = nil
            }
        }
    }

    private func metadataHydrationCandidates(for ids: [String]) -> [MetadataHydrationCandidate] {
        LibraryMetadataHydrationPolicy.candidates(for: ids, mediaItems: mediaItems)
    }

    private func createFolder(named name: String, in targetList: UserLibraryEntry.ListType) async -> String? {
        guard let normalizedName = LibraryFolderCreationPolicy.normalizedName(name) else {
            return "Folder name cannot be empty."
        }

        loadTask?.cancel()
        statusMessage = nil
        actionError = nil
        do {
            let existingFolders = try await appState.database.fetchAllLibraryFolders(listType: targetList)
            let alreadyExists = existingFolders.contains(where: {
                !$0.isSystem && $0.name.caseInsensitiveCompare(normalizedName) == .orderedSame
            })
            let folder = try await appState.database.createLibraryFolder(name: normalizedName, listType: targetList)
            selectedFolderID = folder.id
            actionError = nil
            statusMessage = alreadyExists ? "Using existing folder \(folder.name)." : "Created \(folder.name)."
            NotificationCenter.default.post(name: .libraryDidChange, object: nil)
            await loadSelection()
            return alreadyExists ? "A folder named \"\(folder.name)\" already exists." : nil
        } catch {
            let appError = LibraryActionFailurePolicy.appError(for: error, action: .createFolder)
            statusMessage = nil
            actionError = appError
            return appError.errorDescription
        }
    }

    private func move(entry: UserLibraryEntry, to folder: LibraryFolder) {
        guard entry.listType == selectedList else { return }
        let destinationLabel = LibraryFolderLabelPolicy.fullPath(for: folder, in: allFolderOptions)

        loadTask?.cancel()
        statusMessage = nil
        actionError = nil
        loadTask = Task {
            do {
                try await appState.database.moveLibraryEntry(
                    mediaId: entry.mediaId,
                    listType: entry.listType,
                    toFolderId: folder.id
                )
                actionError = nil
                statusMessage = "Moved to \(destinationLabel)."
                NotificationCenter.default.post(name: .libraryDidChange, object: nil)
                await loadSelection()
            } catch {
                statusMessage = nil
                actionError = LibraryActionFailurePolicy.appError(for: error, action: .moveTitle)
            }
        }
    }

    private func remove(entry: UserLibraryEntry) {
        guard entry.listType == selectedList else { return }

        loadTask?.cancel()
        statusMessage = nil
        actionError = nil
        loadTask = Task {
            do {
                try await appState.database.removeFromLibrary(mediaId: entry.mediaId, listType: entry.listType)
                actionError = nil
                statusMessage = "Removed from \(entry.listType.displayName)."
                NotificationCenter.default.post(name: .libraryDidChange, object: nil)
                await loadSelection()
            } catch {
                statusMessage = nil
                actionError = LibraryActionFailurePolicy.appError(
                    for: error,
                    action: .removeTitle(listName: entry.listType.displayName)
                )
            }
        }
    }

    @MainActor
    private func refreshTitleDuplicates() {
        guard LibraryTitleRefreshPolicy.canStartRefresh(selectedList: selectedList, isRefreshing: isRefreshingTitleDuplicates) else {
            return
        }

        let listType = selectedList
        loadTask?.cancel()
        isRefreshingTitleDuplicates = true
        actionError = nil
        statusMessage = LibraryTitleRefreshPolicy.refreshingMessage(for: listType)

        loadTask = Task {
            defer { isRefreshingTitleDuplicates = false }

            do {
                let removedCount = try await appState.database
                    .dedupeLibraryEntriesByTitleEquivalence(listType: listType)
                _ = try await appState.database.pruneEmptyManualFolders()

                actionError = nil
                statusMessage = LibraryTitleRefreshPolicy.completionMessage(
                    for: listType,
                    removedCount: removedCount
                )
                NotificationCenter.default.post(name: .libraryDidChange, object: nil)
                await loadSelection()
            } catch {
                statusMessage = nil
                actionError = LibraryActionFailurePolicy.appError(
                    for: error,
                    action: .refreshTitles(listName: listType.displayName)
                )
            }
        }
    }

    private func commitFolderReorder(_ reorderedIDs: [String]) {
        let currentIDs = userFolders.map(\.id)
        guard LibraryFolderReorderPolicy.shouldPersist(reorderedIDs: reorderedIDs, currentIDs: currentIDs) else {
            return
        }
        persistFolderOrder(reorderedIDs)
    }

    private func persistFolderOrder(_ reorderedIDs: [String]) {
        let listType = selectedList
        let loadToken = selectionLoadToken
        loadTask?.cancel()
        statusMessage = nil
        actionError = nil
        loadTask = Task {
            do {
                try await appState.database.reorderLibraryFolders(
                    ids: reorderedIDs,
                    listType: listType
                )
                actionError = nil
                statusMessage = "Folder order updated."
                if selectedList == listType {
                    await loadFolders(loadToken: loadToken)
                }
            } catch {
                statusMessage = nil
                actionError = LibraryActionFailurePolicy.appError(for: error, action: .reorderFolders)
            }
        }
    }

    private func delete(folder: LibraryFolder) {
        guard folder.isSystem == false else { return }
        let deletedLabel = LibraryFolderLabelPolicy.fullPath(for: folder, in: allFolderOptions)

        loadTask?.cancel()
        statusMessage = nil
        actionError = nil
        loadTask = Task {
            do {
                try await appState.database.deleteLibraryFolder(id: folder.id, listType: folder.listType)
                if selectedFolderID == folder.id {
                    selectedFolderID = nil
                }
                actionError = nil
                statusMessage = "Deleted \(deletedLabel)."
                NotificationCenter.default.post(name: .libraryDidChange, object: nil)
                await loadSelection()
            } catch {
                statusMessage = nil
                actionError = LibraryActionFailurePolicy.appError(for: error, action: .deleteFolder)
            }
        }
    }
}

private struct FolderChipDropDelegate: DropDelegate {
    let destinationFolderID: String
    @Binding var orderedFolderIDs: [String]
    @Binding var draggedFolderID: String?
    let onCommit: ([String]) -> Void

    func dropEntered(info: DropInfo) {
        guard let reorderedIDs = LibraryFolderReorderPolicy.reorderedIDs(
            orderedFolderIDs: orderedFolderIDs,
            draggedFolderID: draggedFolderID,
            destinationFolderID: destinationFolderID
        ) else {
            return
        }

        withAnimation(.easeInOut(duration: 0.14)) {
            orderedFolderIDs = reorderedIDs
        }
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: .move)
    }

    func performDrop(info: DropInfo) -> Bool {
        draggedFolderID = nil
        onCommit(orderedFolderIDs)
        return true
    }
}

private struct CreateLibraryFolderSheet: View {
    let listType: UserLibraryEntry.ListType
    let onCreate: (String, UserLibraryEntry.ListType) async -> String?

    @Environment(\.dismiss) private var dismiss
    @State private var folderName = ""
    @State private var errorMessage: String?
    @State private var isSubmitting = false
    @FocusState private var isNameFieldFocused: Bool
    private let autoFocusesNameField: Bool

    init(
        listType: UserLibraryEntry.ListType,
        initialFolderName: String = "",
        initialErrorMessage: String? = nil,
        initialIsSubmitting: Bool = false,
        autoFocusesNameField: Bool = true,
        onCreate: @escaping (String, UserLibraryEntry.ListType) async -> String?
    ) {
        self.listType = listType
        self.onCreate = onCreate
        _folderName = State(initialValue: initialFolderName)
        _errorMessage = State(initialValue: initialErrorMessage)
        _isSubmitting = State(initialValue: initialIsSubmitting)
        self.autoFocusesNameField = autoFocusesNameField
    }

    private var canSubmit: Bool {
        LibraryFolderCreationPolicy.normalizedName(folderName) != nil && !isSubmitting
    }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 14) {
                Text("Create a folder in \(listType.displayName).")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                TextField("Folder name", text: $folderName)
                    .textFieldStyle(.roundedBorder)
                    .focused($isNameFieldFocused)
                    .submitLabel(.done)
                    .onSubmit {
                        submit()
                    }

                if let errorMessage, !errorMessage.isEmpty {
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundStyle(.red)
                }

                Spacer(minLength: 0)
            }
            .padding(20)
            .navigationTitle("Create Folder")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismissSafely()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button(isSubmitting ? "Creating..." : "Create") {
                        submit()
                    }
                    .disabled(!canSubmit)
                }
            }
            .onAppear {
                guard autoFocusesNameField else { return }
                Task { @MainActor in
                    try? await Task.sleep(for: .milliseconds(120))
                    isNameFieldFocused = true
                }
            }
        }
        .frame(minWidth: 360, minHeight: 190)
    }

    private func dismissSafely() {
        isNameFieldFocused = false
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: LibraryFolderCreationPolicy.keyboardDismissDelayMilliseconds * 1_000_000)
            dismiss()
        }
    }

    private func submit() {
        guard !isSubmitting else { return }
        guard let normalizedName = LibraryFolderCreationPolicy.normalizedName(folderName) else { return }

        isSubmitting = true
        errorMessage = nil

        Task {
            let creationError = await onCreate(normalizedName, listType)
            await MainActor.run {
                isSubmitting = false
                if let creationError {
                    errorMessage = creationError
                    isNameFieldFocused = true
                } else {
                    dismissSafely()
                }
            }
        }
    }
}
