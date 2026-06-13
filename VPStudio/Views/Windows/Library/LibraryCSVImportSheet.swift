import SwiftUI
import UniformTypeIdentifiers

enum LibraryCSVImportPickerMode: Hashable, Identifiable, Sendable {
    case csvFiles
    case folder

    var id: Self { self }
}

enum LibraryCSVImportSheetPolicy {
    static let createNewFolderOption = "__create_new_folder_option__"

    static func isPickerPresented(mode: LibraryCSVImportPickerMode?) -> Bool {
        mode != nil
    }

    static func activeContentTypes(
        mode: LibraryCSVImportPickerMode?,
        supportedCSVTypes: [UTType] = supportedCSVTypes()
    ) -> [UTType] {
        mode == .folder ? [.folder] : supportedCSVTypes
    }

    static func destinationFolderListTypes(
        for destination: LibraryCSVImportDestination
    ) -> [UserLibraryEntry.ListType] {
        switch destination {
        case .watchlist:
            return [.watchlist]
        case .favorites:
            return [.favorites]
        case .auto:
            return [.watchlist, .favorites]
        case .history:
            return []
        }
    }

    static func destinationSupportsFolders(_ destination: LibraryCSVImportDestination) -> Bool {
        !destinationFolderListTypes(for: destination).isEmpty
    }

    static func shouldShowCustomFolderField(
        existingFolderOptions: [String],
        selectedExistingFolderName: String
    ) -> Bool {
        existingFolderOptions.isEmpty || selectedExistingFolderName == createNewFolderOption
    }

    static func selectedManualFolderName(
        existingFolderOptions: [String],
        selectedExistingFolderName: String,
        typedFolderName: String
    ) -> String {
        let selectedName = shouldShowCustomFolderField(
            existingFolderOptions: existingFolderOptions,
            selectedExistingFolderName: selectedExistingFolderName
        ) ? typedFolderName : selectedExistingFolderName
        return selectedName.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func supportedCSVTypes(
        from candidates: [UTType?] = [
            UTType.commaSeparatedText,
            UTType(filenameExtension: "csv"),
            UTType.plainText,
            UTType.text,
        ]
    ) -> [UTType] {
        let compact = candidates.compactMap { $0 }
        return compact.isEmpty ? [.data] : compact
    }

    static func selectedExistingFolderName(
        afterLoading uniqueNames: [String],
        currentSelection: String
    ) -> String {
        guard !uniqueNames.isEmpty else {
            return createNewFolderOption
        }
        return uniqueNames.first {
            $0.caseInsensitiveCompare(currentSelection) == .orderedSame
        } ?? uniqueNames[0]
    }

    static func requiresManualSubfolderName(
        fileCount: Int,
        importToFolder: Bool,
        destinationSupportsFolders: Bool,
        autoSubfolderPerFile: Bool,
        manualFolderName: String
    ) -> Bool {
        fileCount > 1
            && importToFolder
            && destinationSupportsFolders
            && !autoSubfolderPerFile
            && manualFolderName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    static func canonicalFolderNames(from names: [String]) -> [String] {
        var uniqueNames: [String] = []
        let sorted = names
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }

        for name in sorted {
            if uniqueNames.contains(where: { $0.caseInsensitiveCompare(name) == .orderedSame }) {
                continue
            }
            uniqueNames.append(name)
        }
        return uniqueNames
    }
}

struct LibraryCSVImportSheet: View {
    let onImportComplete: (LibraryCSVImportSummary) -> Void

    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss

    @State private var csvImportDestination: LibraryCSVImportDestination = .auto
    @State private var csvImportRatings = true
    @State private var csvPromoteLikedToFavorites = true
    @State private var folderName = ""
    @State private var importToFolder = true
    @State private var autoSubfolderPerFile = true
    @State private var existingFolderOptions: [String] = []
    @State private var selectedExistingFolderName = Self.createNewFolderOption
    @State private var importPickerMode: LibraryCSVImportPickerMode?
    @State private var csvImportInFlight = false
    @State private var csvImportError: String?
    @State private var csvImportNotice: String?
    @State private var importSummary: LibraryCSVImportSummary?
    @State private var multiImportSummaries: [LibraryCSVImportSummary] = []
    @State private var importDiagnostics: [String] = []

    private static let createNewFolderOption = LibraryCSVImportSheetPolicy.createNewFolderOption
    private let disablesAutomaticTasks: Bool
    private let enablesRuntimeImportControls: Bool
    private let onFolderOptionsRefreshed: (@MainActor ([String], String) -> Void)?
    private let onRuntimeImportControlsReady: (@MainActor () -> Void)?

    init(
        initialDestination: LibraryCSVImportDestination = .auto,
        initialImportRatings: Bool = true,
        initialPromoteLikedToFavorites: Bool = true,
        initialFolderName: String = "",
        initialImportToFolder: Bool = true,
        initialAutoSubfolderPerFile: Bool = true,
        initialExistingFolderOptions: [String] = [],
        initialSelectedExistingFolderName: String = LibraryCSVImportSheetPolicy.createNewFolderOption,
        initialImportInFlight: Bool = false,
        initialImportError: String? = nil,
        initialImportNotice: String? = nil,
        initialImportSummary: LibraryCSVImportSummary? = nil,
        initialMultiImportSummaries: [LibraryCSVImportSummary] = [],
        initialImportDiagnostics: [String] = [],
        disablesAutomaticTasks: Bool = false,
        enablesRuntimeImportControls: Bool = false,
        onFolderOptionsRefreshed: (@MainActor ([String], String) -> Void)? = nil,
        onRuntimeImportControlsReady: (@MainActor () -> Void)? = nil,
        onImportComplete: @escaping (LibraryCSVImportSummary) -> Void
    ) {
        self.onImportComplete = onImportComplete
        _csvImportDestination = State(initialValue: initialDestination)
        _csvImportRatings = State(initialValue: initialImportRatings)
        _csvPromoteLikedToFavorites = State(initialValue: initialPromoteLikedToFavorites)
        _folderName = State(initialValue: initialFolderName)
        _importToFolder = State(initialValue: initialImportToFolder)
        _autoSubfolderPerFile = State(initialValue: initialAutoSubfolderPerFile)
        _existingFolderOptions = State(initialValue: initialExistingFolderOptions)
        _selectedExistingFolderName = State(initialValue: initialSelectedExistingFolderName)
        _csvImportInFlight = State(initialValue: initialImportInFlight)
        _csvImportError = State(initialValue: initialImportError)
        _csvImportNotice = State(initialValue: initialImportNotice)
        _importSummary = State(initialValue: initialImportSummary)
        _multiImportSummaries = State(initialValue: initialMultiImportSummaries)
        _importDiagnostics = State(initialValue: initialImportDiagnostics)
        self.disablesAutomaticTasks = disablesAutomaticTasks
        self.enablesRuntimeImportControls = enablesRuntimeImportControls
        self.onFolderOptionsRefreshed = onFolderOptionsRefreshed
        self.onRuntimeImportControlsReady = onRuntimeImportControlsReady
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Destination") {
                    Picker("Import to", selection: $csvImportDestination) {
                        ForEach(LibraryCSVImportDestination.allCases, id: \.self) { destination in
                            Text(destination.displayName).tag(destination)
                        }
                    }
                }

                Section("Folder") {
                    Toggle("Import into a named folder", isOn: $importToFolder)

                    if importToFolder {
                        if destinationSupportsFolders {
                            Toggle("Auto subfolder from each filename", isOn: $autoSubfolderPerFile)

                            if autoSubfolderPerFile {
                                Text("Each CSV is imported into its own subfolder (derived from filename).")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            } else {
                                if !existingFolderOptions.isEmpty {
                                    Picker("Existing subfolder", selection: $selectedExistingFolderName) {
                                        Text("Create New Folder").tag(Self.createNewFolderOption)
                                        ForEach(existingFolderOptions, id: \.self) { name in
                                            Text(name).tag(name)
                                        }
                                    }
                                }

                                if shouldShowCustomFolderField {
                                    TextField("Subfolder name", text: $folderName)
                                        .textFieldStyle(.roundedBorder)

                                    Text("All selected CSV files will import into this subfolder. If it exists, it will be reused.")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                } else {
                                    Text("All selected CSV files will import into “\(selectedExistingFolderName)”.")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        } else {
                            Text("History imports do not use folders. This setting is ignored for History destination.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                Section("Ratings") {
                    Toggle("Import ratings into AI profile", isOn: $csvImportRatings)
                    Toggle("Promote liked ratings to Favorites (Auto)", isOn: $csvPromoteLikedToFavorites)
                        .disabled(!csvImportRatings || csvImportDestination != .auto)
                }

                Section {
                    Button(csvImportInFlight ? "Importing..." : "Choose CSV Files", systemImage: "square.and.arrow.down") {
                        importPickerMode = .csvFiles
                    }
                    .disabled(csvImportInFlight)

                    Button(csvImportInFlight ? "Importing..." : "Import from Folder", systemImage: "folder") {
                        importPickerMode = .folder
                    }
                    .disabled(csvImportInFlight)

                    Text("Choose individual CSV files, or select a folder to import all CSVs inside it. Supports IMDb exports and VPStudio exports.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if !multiImportSummaries.isEmpty {
                    Section("Import Results (\(multiImportSummaries.count) file\(multiImportSummaries.count == 1 ? "" : "s"))") {
                        let totals = Self.aggregatedSummary(multiImportSummaries)
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Total rows: \(totals.rowsImported)/\(totals.rowsRead) imported (\(totals.rowsSkipped) skipped)")
                            Text("Created: \(totals.mediaItemsCreated) media \u{00B7} Updated: \(totals.mediaItemsUpdated)")
                            Text("Watchlist: \(totals.watchlistImported) \u{00B7} Favorites: \(totals.favoritesImported) \u{00B7} History: \(totals.historyImported) \u{00B7} Ratings: \(totals.ratingsImported)")
                        }
                        .font(.caption)
                        .foregroundStyle(.secondary)

                        ForEach(Array(multiImportSummaries.enumerated()), id: \.offset) { _, summary in
                            VStack(alignment: .leading, spacing: 2) {
                                if let folderName = summary.targetFolderName {
                                    Text(folderName)
                                        .font(.caption)
                                        .fontWeight(.semibold)
                                }
                                Text("\(summary.detectedFormat.displayName) \u{00B7} \(summary.rowsImported) imported \u{00B7} W:\(summary.watchlistImported) F:\(summary.favoritesImported) H:\(summary.historyImported)")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                } else if let summary = importSummary {
                    Section("Import Results") {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Format: \(summary.detectedFormat.displayName)")
                            Text("Rows: \(summary.rowsImported)/\(summary.rowsRead) imported (\(summary.rowsSkipped) skipped)")
                            Text("Created: \(summary.mediaItemsCreated) media \u{00B7} Updated: \(summary.mediaItemsUpdated)")
                            Text("Watchlist: \(summary.watchlistImported) \u{00B7} Favorites: \(summary.favoritesImported) \u{00B7} History: \(summary.historyImported) \u{00B7} Ratings: \(summary.ratingsImported)")
                            if let folderName = summary.targetFolderName {
                                Text("Folder: \(folderName)")
                            }
                        }
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }
                }

                if let error = csvImportError {
                    Section {
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                }

                if let notice = csvImportNotice {
                    Section {
                        Text(notice)
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }
                }

                if !importDiagnostics.isEmpty {
                    Section("Diagnostics") {
                        Text("Build marker: import-diag-20260225b")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Text("Trace file: \(Self.traceLogURL.path)")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .textSelection(.enabled)
                        ForEach(Array(importDiagnostics.suffix(10).enumerated()), id: \.offset) { _, line in
                            Text(line)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .textSelection(.enabled)
                        }
                    }
                }
            }
            .navigationTitle("Import CSV")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .fileImporter(
                isPresented: isPickerPresented,
                allowedContentTypes: activeContentTypes,
                allowsMultipleSelection: importPickerMode != .folder
            ) { result in
                let mode = importPickerMode
                importPickerMode = nil
                trace("picker result mode=\(String(describing: mode))")
                switch mode {
                case .csvFiles:
                    Task { await importCSVFiles(result) }
                case .folder:
                    Task { await importFolder(result) }
                case nil:
                    break
                }
            }
            .task {
                guard !disablesAutomaticTasks else { return }
                await refreshExistingFolderOptions()
            }
            .onChange(of: csvImportDestination) { _, _ in
                guard !disablesAutomaticTasks else { return }
                Task { await refreshExistingFolderOptions() }
            }
            .modifier(LibraryCSVImportControlHandlers(
                isEnabled: enablesRuntimeImportControls,
                onReady: onRuntimeImportControlsReady,
                onImportFiles: { urls in
                    Task { await importCSVFiles(.success(urls)) }
                },
                onImportFolder: { folderURL in
                    Task { await importFolder(.success([folderURL])) }
                }
            ))
        }
        .frame(minWidth: 400, minHeight: 440)
    }

    /// Single binding that drives the one `.fileImporter` modifier.
    private var isPickerPresented: Binding<Bool> {
        Binding(
            get: { LibraryCSVImportSheetPolicy.isPickerPresented(mode: importPickerMode) },
            // Keep mode until fileImporter completion callback reads it.
            // Clearing here races with callback and can drop the import action.
            set: { _ in }
        )
    }

    /// Content types switch based on which button was tapped.
    private var activeContentTypes: [UTType] {
        LibraryCSVImportSheetPolicy.activeContentTypes(
            mode: importPickerMode,
            supportedCSVTypes: supportedCSVTypes
        )
    }

    private var destinationFolderListTypes: [UserLibraryEntry.ListType] {
        LibraryCSVImportSheetPolicy.destinationFolderListTypes(for: csvImportDestination)
    }

    private var destinationSupportsFolders: Bool {
        LibraryCSVImportSheetPolicy.destinationSupportsFolders(csvImportDestination)
    }

    private var shouldShowCustomFolderField: Bool {
        LibraryCSVImportSheetPolicy.shouldShowCustomFolderField(
            existingFolderOptions: existingFolderOptions,
            selectedExistingFolderName: selectedExistingFolderName
        )
    }

    private var selectedManualFolderName: String {
        LibraryCSVImportSheetPolicy.selectedManualFolderName(
            existingFolderOptions: existingFolderOptions,
            selectedExistingFolderName: selectedExistingFolderName,
            typedFolderName: folderName
        )
    }

    private var supportedCSVTypes: [UTType] {
        LibraryCSVImportSheetPolicy.supportedCSVTypes()
    }

    @MainActor
    private func importCSVFiles(_ result: Result<[URL], any Error>) async {
        do {
            let urls = try result.get()
            guard !urls.isEmpty else { return }

            trace("importCSVFiles start files=\(urls.count) importToFolder=\(importToFolder) autoSubfolderPerFile=\(autoSubfolderPerFile)")
            csvImportError = nil
            csvImportNotice = nil
            importSummary = nil
            multiImportSummaries = []
            csvImportInFlight = true
            defer { csvImportInFlight = false }

            let manualFolderName = selectedManualFolderName
            let useAutoSubfolderPerFile = importToFolder && destinationSupportsFolders && autoSubfolderPerFile

            if LibraryCSVImportSheetPolicy.requiresManualSubfolderName(
                fileCount: urls.count,
                importToFolder: importToFolder,
                destinationSupportsFolders: destinationSupportsFolders,
                autoSubfolderPerFile: useAutoSubfolderPerFile,
                manualFolderName: manualFolderName
            ) {
                csvImportError = "Enter a subfolder name, or enable auto subfolder by filename."
                trace("importCSVFiles validation error=missing manual subfolder name")
                return
            }

            // Single file — use existing single-import behavior
            if urls.count == 1 {
                let summary = try await importSingleCSV(
                    urls[0],
                    autoFolderFromFilename: useAutoSubfolderPerFile
                )
                let prunedFolders = (try? await appState.database.pruneEmptyManualFolders()) ?? 0
                importSummary = summary
                multiImportSummaries = []
                trace("single file=\(urls[0].lastPathComponent) \(Self.summaryLogLine(summary))")
                if !Self.hasLibraryChanges(in: summary) {
                    csvImportNotice = Self.noLibraryChangesNotice(anyRatingsImported: summary.ratingsImported > 0)
                }
                if prunedFolders > 0 && !Self.hasLibraryChanges(in: summary) {
                    NotificationCenter.default.post(name: .libraryDidChange, object: nil)
                }
                onImportComplete(summary)
                return
            }

            // Multi-file — either per-file auto subfolders, or one manual subfolder.
            var summaries: [LibraryCSVImportSummary] = []
            var anyLibraryChange = false
            var anyRatingChange = false

            for url in urls {
                do {
                    let summary = try await importSingleCSV(
                        url,
                        autoFolderFromFilename: useAutoSubfolderPerFile,
                        postNotifications: false
                    )
                    summaries.append(summary)
                    trace("file=\(url.lastPathComponent) \(Self.summaryLogLine(summary))")
                    if Self.hasLibraryChanges(in: summary) {
                        anyLibraryChange = true
                    }
                    if summary.ratingsImported > 0 {
                        anyRatingChange = true
                    }
                } catch {
                    trace("file=\(url.lastPathComponent) error=\(error.localizedDescription)")
                    // Record error for this file but continue with the rest
                    csvImportError = (csvImportError ?? "") + "\(url.lastPathComponent): \(error.localizedDescription)\n"
                }
            }

            multiImportSummaries = summaries
            importSummary = nil

            if !summaries.isEmpty && !anyLibraryChange {
                csvImportNotice = Self.noLibraryChangesNotice(anyRatingsImported: anyRatingChange)
            }

            if anyLibraryChange {
                NotificationCenter.default.post(name: .libraryDidChange, object: nil)
            }
            if anyRatingChange {
                NotificationCenter.default.post(name: .tasteProfileDidChange, object: nil)
            }

            // Clean up any empty folders left from previous imports
            let prunedFolders = (try? await appState.database.pruneEmptyManualFolders()) ?? 0
            if prunedFolders > 0 && !anyLibraryChange {
                NotificationCenter.default.post(name: .libraryDidChange, object: nil)
            }

            if !summaries.isEmpty {
                let aggregate = Self.aggregatedSummary(summaries)
                trace("aggregate files=\(summaries.count) \(Self.summaryLogLine(aggregate))")
                onImportComplete(aggregate)
            }
        } catch {
            csvImportNotice = nil
            trace("import error=\(error.localizedDescription)")
            csvImportError = error.localizedDescription
        }
    }

    @MainActor
    private func importFolder(_ result: Result<[URL], any Error>) async {
        do {
            let urls = try result.get()
            guard let folderURL = urls.first else { return }
            trace("importFolder path=\(folderURL.path)")

            let hasSecurityScope = folderURL.startAccessingSecurityScopedResource()
            defer {
                if hasSecurityScope {
                    folderURL.stopAccessingSecurityScopedResource()
                }
            }

            let contents = try FileManager.default.contentsOfDirectory(
                at: folderURL,
                includingPropertiesForKeys: nil,
                options: [.skipsHiddenFiles]
            )
            let csvURLs = contents.filter { $0.pathExtension.lowercased() == "csv" }
                .sorted { $0.lastPathComponent.localizedCaseInsensitiveCompare($1.lastPathComponent) == .orderedAscending }

            guard !csvURLs.isEmpty else {
                csvImportNotice = nil
                csvImportError = "No CSV files found in the selected folder."
                trace("importFolder no csv files")
                return
            }

            trace("importFolder csv files=\(csvURLs.count)")
            // Feed into existing multi-file import path
            await importCSVFiles(.success(csvURLs))
        } catch {
            csvImportNotice = nil
            trace("importFolder error=\(error.localizedDescription)")
            csvImportError = error.localizedDescription
        }
    }

    @MainActor
    private func importSingleCSV(
        _ url: URL,
        autoFolderFromFilename: Bool = false,
        postNotifications: Bool = true
    ) async throws -> LibraryCSVImportSummary {
        trace("importSingleCSV file=\(url.lastPathComponent) autoFolder=\(autoFolderFromFilename)")
        let hasSecurityScope = url.startAccessingSecurityScopedResource()
        defer {
            if hasSecurityScope {
                url.stopAccessingSecurityScopedResource()
            }
        }
        trace("importSingleCSV stats=\(Self.debugFileStats(at: url))")

        let resolvedFolderName: String?
        if autoFolderFromFilename {
            // Multi-import: always use filename as folder name
            resolvedFolderName = LibraryCSVImportService.defaultFolderName(from: url)
        } else if importToFolder, destinationSupportsFolders {
            // Single import: use selected/typed folder, defaulting to filename when empty.
            var manualName = selectedManualFolderName
            if manualName.isEmpty {
                folderName = LibraryCSVImportService.defaultFolderName(from: url)
                manualName = folderName.trimmingCharacters(in: .whitespacesAndNewlines)
            }
            resolvedFolderName = manualName.isEmpty ? nil : manualName
        } else {
            resolvedFolderName = nil
        }

        // When destination is Auto, infer from filename so items land in the right list
        let resolvedDestination: LibraryCSVImportDestination
        if csvImportDestination == .auto,
           let inferred = LibraryCSVImportService.inferredDestination(from: url) {
            resolvedDestination = inferred
        } else {
            resolvedDestination = csvImportDestination
        }
        trace("importSingleCSV destination=\(resolvedDestination.rawValue) folder=\(resolvedFolderName ?? "nil")")

        let options = LibraryCSVImportOptions(
            destination: resolvedDestination,
            importRatings: csvImportRatings,
            promoteLikedRatingsToFavorites: csvPromoteLikedToFavorites,
            targetFolderName: resolvedFolderName
        )

        let summary = try await appState.libraryCSVImportService.importCSV(from: url, options: options)

        // Refresh library only when list entries actually changed.
        if postNotifications && Self.hasLibraryChanges(in: summary) {
            NotificationCenter.default.post(name: .libraryDidChange, object: nil)
        }
        if postNotifications && summary.ratingsImported > 0 {
            NotificationCenter.default.post(name: .tasteProfileDidChange, object: nil)
        }

        return summary
    }

    @MainActor
    private func refreshExistingFolderOptions() async {
        guard destinationSupportsFolders else {
            existingFolderOptions = []
            selectedExistingFolderName = Self.createNewFolderOption
            onFolderOptionsRefreshed?(existingFolderOptions, selectedExistingFolderName)
            return
        }

        do {
            var names: [String] = []
            for listType in destinationFolderListTypes {
                let folders = try await appState.database.fetchAllLibraryFolders(listType: listType)
                names.append(contentsOf: folders.filter { !$0.isSystem }.map(\.name))
            }

            let uniqueNames = LibraryCSVImportSheetPolicy.canonicalFolderNames(from: names)

            existingFolderOptions = uniqueNames
            selectedExistingFolderName = LibraryCSVImportSheetPolicy.selectedExistingFolderName(
                afterLoading: uniqueNames,
                currentSelection: selectedExistingFolderName
            )
            onFolderOptionsRefreshed?(existingFolderOptions, selectedExistingFolderName)
        } catch {
            existingFolderOptions = []
            selectedExistingFolderName = Self.createNewFolderOption
            onFolderOptionsRefreshed?(existingFolderOptions, selectedExistingFolderName)
            trace("existing folders load error=\(error.localizedDescription)")
        }
    }

    nonisolated static func aggregatedSummary(_ summaries: [LibraryCSVImportSummary]) -> LibraryCSVImportSummary {
        var total = LibraryCSVImportSummary(
            detectedFormat: .generic,
            rowsRead: 0, rowsImported: 0, rowsSkipped: 0,
            mediaItemsCreated: 0, mediaItemsUpdated: 0,
            watchlistImported: 0, favoritesImported: 0,
            historyImported: 0, ratingsImported: 0
        )
        for s in summaries {
            total.rowsRead += s.rowsRead
            total.rowsImported += s.rowsImported
            total.rowsSkipped += s.rowsSkipped
            total.mediaItemsCreated += s.mediaItemsCreated
            total.mediaItemsUpdated += s.mediaItemsUpdated
            total.watchlistImported += s.watchlistImported
            total.favoritesImported += s.favoritesImported
            total.historyImported += s.historyImported
            total.ratingsImported += s.ratingsImported
        }
        return total
    }

    nonisolated static func hasLibraryChanges(in summary: LibraryCSVImportSummary) -> Bool {
        summary.watchlistImported > 0 || summary.favoritesImported > 0 || summary.historyImported > 0
    }

    nonisolated static func noLibraryChangesNotice(anyRatingsImported: Bool) -> String {
        if anyRatingsImported {
            return "Import finished, but no new library items were added. Ratings were imported."
        }
        return "Import finished, but no new library items were added. The imported titles may already exist."
    }

    nonisolated static func summaryLogLine(_ summary: LibraryCSVImportSummary) -> String {
        "rows=\(summary.rowsImported)/\(summary.rowsRead) skipped=\(summary.rowsSkipped) W=\(summary.watchlistImported) F=\(summary.favoritesImported) H=\(summary.historyImported) R=\(summary.ratingsImported)"
    }

    nonisolated static func debugFileStats(at url: URL) -> String {
        guard let data = try? Data(contentsOf: url, options: [.mappedIfSafe]) else {
            return "read=failed path=\(url.path)"
        }
        let text = String(data: data, encoding: .utf8)
            ?? String(data: data, encoding: .utf16)
            ?? String(data: data, encoding: .isoLatin1)
        guard let text else {
            return "bytes=\(data.count) text=undecodable"
        }
        let header = text
            .split(whereSeparator: \.isNewline)
            .first
            .map(String.init)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let lineCount = text.split(whereSeparator: \.isNewline).count
        return "bytes=\(data.count) lines=\(lineCount) header=\"\(header.prefix(80))\""
    }

    @MainActor
    private func trace(_ message: String) {
        let timestamp = ISO8601DateFormatter().string(from: Date())
        let line = "[\(timestamp)] \(message)"
        importDiagnostics.append(line)
        if importDiagnostics.count > 80 {
            importDiagnostics.removeFirst(importDiagnostics.count - 80)
        }
        appendTraceLine(line)
    }

    private func appendTraceLine(_ line: String) {
        guard let data = "\(line)\n".data(using: .utf8) else { return }
        let url = Self.traceLogURL
        if FileManager.default.fileExists(atPath: url.path),
           let handle = try? FileHandle(forWritingTo: url) {
            defer { try? handle.close() }
            do {
                try handle.seekToEnd()
                try handle.write(contentsOf: data)
                return
            } catch {
                // Fall through to rewrite when append fails.
            }
        }
        try? data.write(to: url)
    }

    private static var traceLogURL: URL {
        FileManager.default.temporaryDirectory.appendingPathComponent("vpstudio-import-trace.log")
    }
}

private struct LibraryCSVImportControlHandlers: ViewModifier {
    let isEnabled: Bool
    let onReady: (@MainActor () -> Void)?
    let onImportFiles: ([URL]) -> Void
    let onImportFolder: (URL) -> Void

    func body(content: Content) -> some View {
        content
            .onAppear {
                guard isEnabled else { return }
                onReady?()
            }
            .onReceive(NotificationCenter.default.publisher(for: .libraryCSVImportControlImportFiles)) { notification in
                guard isEnabled, let urls = notification.object as? [URL] else { return }
                onImportFiles(urls)
            }
            .onReceive(NotificationCenter.default.publisher(for: .libraryCSVImportControlImportFolder)) { notification in
                guard isEnabled, let folderURL = notification.object as? URL else { return }
                onImportFolder(folderURL)
            }
    }
}
