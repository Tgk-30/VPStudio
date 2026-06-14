import Foundation
#if os(macOS)
import AppKit
#endif
import Observation

protocol DownloadManaging: Sendable {
    func listDownloads() async throws -> [DownloadTask]
    func cancelDownload(id: String) async
    func retryDownload(id: String) async throws
    func removeDownload(id: String) async throws
    func removeDownloads(mediaId: String) async throws
}

extension DownloadManager: DownloadManaging {}

enum DownloadProgressPolicy {
    static func clampedUnitProgress(_ value: Double) -> Double {
        guard value.isFinite else { return 0 }
        return min(max(value, 0), 1)
    }

    static func normalizedProgress(
        progress: Double,
        bytesWritten: Int64,
        totalBytes: Int64?,
        status: DownloadStatus
    ) -> Double {
        if let totalBytes, totalBytes > 0 {
            return clampedUnitProgress(Double(bytesWritten) / Double(totalBytes))
        }

        if status == .completed {
            return 1
        }

        return clampedUnitProgress(progress)
    }

    static func latestUpdatedAt(in tasks: [DownloadTask]) -> Date {
        tasks.map(\.updatedAt).max() ?? .distantPast
    }
}

struct DownloadMediaGroup: Identifiable {
    var id: String { mediaId }
    let mediaId: String
    let mediaTitle: String
    let mediaType: String
    let posterPath: String?
    var tasks: [DownloadTask]

    var posterURL: URL? {
        guard let path = posterPath else { return nil }
        return URL(string: "https://image.tmdb.org/t/p/w342\(path)")
    }

    var completedCount: Int {
        tasks.filter { $0.status == .completed }.count
    }

    var totalCount: Int { tasks.count }

    var overallProgress: Double {
        guard !tasks.isEmpty else { return 0 }
        let normalizedSum = tasks.reduce(0.0) { partial, task in
            partial + DownloadProgressPolicy.normalizedProgress(
                progress: task.progress,
                bytesWritten: task.bytesWritten,
                totalBytes: task.totalBytes,
                status: task.status
            )
        }
        return DownloadProgressPolicy.clampedUnitProgress(normalizedSum / Double(tasks.count))
    }

    var hasActiveDownloads: Bool {
        tasks.contains { !$0.status.isTerminal }
    }
}

enum DownloadSortOption: String, CaseIterable, Identifiable, Sendable {
    case recent, size, name, status
    var id: String { rawValue }
    var label: String {
        switch self {
        case .recent: return "Recent"
        case .size:   return "Size"
        case .name:   return "Name"
        case .status: return "Status"
        }
    }
    var systemImage: String {
        switch self {
        case .recent: return "clock"
        case .size:   return "externaldrive"
        case .name:   return "textformat"
        case .status: return "circle.lefthalf.filled"
        }
    }
}

@Observable
@MainActor
final class DownloadsViewModel {
    var groups: [DownloadMediaGroup] = []
    var tasks: [DownloadTask] = []
    var isLoading = false
    var rootError: AppError?

    var errorMessage: String? {
        rootError?.errorDescription
    }

    private let appState: AppState
    private let downloadManager: any DownloadManaging

    init(appState: AppState, downloadManager: (any DownloadManaging)? = nil) {
        self.appState = appState
        self.downloadManager = downloadManager ?? appState.downloadManager
    }

    func load() async {
        isLoading = true
        defer { isLoading = false }

        do {
            let latestTasks = try await downloadManager.listDownloads()
            guard !Task.isCancelled else { return }
            applyTasks(latestTasks)
        } catch is CancellationError {
            return
        } catch {
            guard !Task.isCancelled else { return }
            rootError = AppError(error)
        }
    }

    func cancel(_ task: DownloadTask) async {
        await downloadManager.cancelDownload(id: task.id)
        applyTasks(tasks.map { existing in
            guard existing.id == task.id else { return existing }
            var updated = existing
            updated.status = .cancelled
            return updated
        })
    }

    func retry(_ task: DownloadTask) async {
        do {
            try await downloadManager.retryDownload(id: task.id)
            applyTasks(tasks.map { existing in
                guard existing.id == task.id else { return existing }
                var updated = existing
                updated.status = .queued
                updated.errorMessage = nil
                return updated
            })
        } catch {
            rootError = AppError(error)
        }
    }

    func remove(_ task: DownloadTask) async {
        do {
            try await downloadManager.removeDownload(id: task.id)
            applyTasks(tasks.filter { $0.id != task.id })
        } catch {
            rootError = AppError(error)
        }
    }

    func removeAll(mediaId: String) async {
        do {
            try await downloadManager.removeDownloads(mediaId: mediaId)
            applyTasks(tasks.filter { $0.mediaId != mediaId })
        } catch {
            rootError = AppError(error)
        }
    }

    func playFile(_ task: DownloadTask) {
        guard task.status == .completed, let fileURL = task.destinationURL else { return }
        #if os(macOS)
        NSWorkspace.shared.open(fileURL)
        #else
        // On visionOS, create a player session from the local file
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
        #endif
    }

    // MARK: - Sections, summary, sorting (UX revamp)

    var sortOption: DownloadSortOption = .recent

    var sortedGroups: [DownloadMediaGroup] {
        switch sortOption {
        case .recent:
            return groups.sorted {
                DownloadProgressPolicy.latestUpdatedAt(in: $0.tasks) > DownloadProgressPolicy.latestUpdatedAt(in: $1.tasks)
            }
        case .size:
            return groups.sorted { groupBytes($0) > groupBytes($1) }
        case .name:
            return groups.sorted { $0.mediaTitle.localizedCaseInsensitiveCompare($1.mediaTitle) == .orderedAscending }
        case .status:
            return groups.sorted { lhs, rhs in
                if lhs.hasActiveDownloads != rhs.hasActiveDownloads { return lhs.hasActiveDownloads }
                return DownloadProgressPolicy.latestUpdatedAt(in: lhs.tasks) > DownloadProgressPolicy.latestUpdatedAt(in: rhs.tasks)
            }
        }
    }

    /// In-progress titles (anything not fully terminal), pinned to the top of the screen.
    var activeGroups: [DownloadMediaGroup] { sortedGroups.filter { $0.hasActiveDownloads } }
    /// Fully-downloaded titles.
    var completedGroups: [DownloadMediaGroup] { sortedGroups.filter { !$0.hasActiveDownloads } }

    var activeTaskCount: Int { tasks.filter { !$0.status.isTerminal }.count }
    var completedTaskCount: Int { tasks.filter { $0.status == .completed }.count }
    var failedTaskCount: Int { tasks.filter { $0.status == .failed }.count }

    /// Total on-disk bytes of completed downloads (for the storage overview).
    var totalDownloadedBytes: Int64 {
        tasks.filter { $0.status == .completed }.compactMap { $0.totalBytes }.reduce(0, +)
    }

    /// Aggregate progress across all active downloads (for the summary progress bar).
    var aggregateActiveProgress: Double {
        let active = tasks.filter { !$0.status.isTerminal }
        guard !active.isEmpty else { return 0 }
        let sum = active.reduce(0.0) {
            $0 + DownloadProgressPolicy.normalizedProgress(
                progress: $1.progress, bytesWritten: $1.bytesWritten, totalBytes: $1.totalBytes, status: $1.status
            )
        }
        return DownloadProgressPolicy.clampedUnitProgress(sum / Double(active.count))
    }

    var hasActiveTasks: Bool { activeTaskCount > 0 }
    var hasCompletedTasks: Bool { completedTaskCount > 0 }
    var hasFailedTasks: Bool { failedTaskCount > 0 }

    private func groupBytes(_ group: DownloadMediaGroup) -> Int64 {
        group.tasks.compactMap { $0.totalBytes ?? $0.expectedBytes }.reduce(0, +)
    }

    // MARK: - Bulk actions

    func clearCompleted() async {
        let completed = tasks.filter { $0.status == .completed }
        for task in completed { try? await downloadManager.removeDownload(id: task.id) }
        applyTasks(tasks.filter { $0.status != .completed })
    }

    func retryAllFailed() async {
        let failed = tasks.filter { $0.status == .failed }
        for task in failed { try? await downloadManager.retryDownload(id: task.id) }
        applyTasks(tasks.map { task in
            guard task.status == .failed else { return task }
            var updated = task
            updated.status = .queued
            updated.errorMessage = nil
            return updated
        })
    }

    func cancelAllActive() async {
        let active = tasks.filter { !$0.status.isTerminal }
        for task in active { await downloadManager.cancelDownload(id: task.id) }
        applyTasks(tasks.map { task in
            guard !task.status.isTerminal else { return task }
            var updated = task
            updated.status = .cancelled
            return updated
        })
    }

    private func applyTasks(_ latestTasks: [DownloadTask]) {
        let sanitizedTasks = latestTasks.map(sanitizedTask)
        tasks = sanitizedTasks
        groups = buildGroups(from: sanitizedTasks)
        rootError = nil
    }

    private func buildGroups(from tasks: [DownloadTask]) -> [DownloadMediaGroup] {
        var groupDict: [String: DownloadMediaGroup] = [:]

        for task in tasks {
            if var existing = groupDict[task.mediaId] {
                existing.tasks.append(task)
                groupDict[task.mediaId] = existing
            } else {
                groupDict[task.mediaId] = DownloadMediaGroup(
                    mediaId: task.mediaId,
                    mediaTitle: task.mediaTitle,
                    mediaType: task.mediaType,
                    posterPath: task.posterPath,
                    tasks: [task]
                )
            }
        }

        return groupDict.values
            .map { group in
                var sorted = group
                sorted.tasks.sort { lhs, rhs in
                    if lhs.episodeSortKey != rhs.episodeSortKey {
                        return lhs.episodeSortKey < rhs.episodeSortKey
                    }
                    return lhs.createdAt < rhs.createdAt
                }
                return sorted
            }
            .sorted {
                DownloadProgressPolicy.latestUpdatedAt(in: $0.tasks) > DownloadProgressPolicy.latestUpdatedAt(in: $1.tasks)
            }
    }

    private func sanitizedTask(_ task: DownloadTask) -> DownloadTask {
        var updated = task
        updated.progress = DownloadProgressPolicy.normalizedProgress(
            progress: task.progress,
            bytesWritten: task.bytesWritten,
            totalBytes: task.totalBytes,
            status: task.status
        )
        return updated
    }
}
