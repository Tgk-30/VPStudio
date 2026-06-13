import Testing
@testable import VPStudio

@Suite("RootNavigationBadgePolicy")
struct RootNavigationBadgePolicyTests {
    @Test
    func activeDownloadCountCountsOnlyInFlightTasks() {
        let tasks = [
            DownloadTask(
                mediaId: "movie-1",
                streamURL: "https://example.com/one.mkv",
                fileName: "one.mkv",
                status: .queued
            ),
            DownloadTask(
                mediaId: "movie-2",
                streamURL: "https://example.com/two.mkv",
                fileName: "two.mkv",
                status: .downloading
            ),
            DownloadTask(
                mediaId: "movie-3",
                streamURL: "https://example.com/three.mkv",
                fileName: "three.mkv",
                status: .completed
            ),
            DownloadTask(
                mediaId: "movie-4",
                streamURL: "https://example.com/four.mkv",
                fileName: "four.mkv",
                status: .failed
            ),
        ]

        #expect(RootNavigationBadgePolicy.activeDownloadCount(from: tasks) == 2)
    }

    @Test
    func activeDownloadCountReturnsZeroForEmptyOrTerminalOnlyTasks() {
        #expect(RootNavigationBadgePolicy.activeDownloadCount(from: []) == 0)

        let terminalTasks = [
            DownloadTask(
                mediaId: "movie-1",
                streamURL: "https://example.com/one.mkv",
                fileName: "one.mkv",
                status: .completed
            ),
            DownloadTask(
                mediaId: "movie-2",
                streamURL: "https://example.com/two.mkv",
                fileName: "two.mkv",
                status: .cancelled
            ),
            DownloadTask(
                mediaId: "movie-3",
                streamURL: "https://example.com/three.mkv",
                fileName: "three.mkv",
                status: .failed
            )
        ]

        #expect(RootNavigationBadgePolicy.activeDownloadCount(from: terminalTasks) == 0)
    }

    @Test
    func settingsWarningCountMatchesTheCurrentStatusSnapshot() {
        var snapshot = SettingsStatusSnapshot()
        snapshot.activeDebridCount = 1
        snapshot.activeIndexerCount = 1
        snapshot.hasTMDBKey = false
        snapshot.aiProvider = .openAI
        snapshot.hasOpenAIKey = true
        snapshot.hasTraktCredentials = true
        snapshot.hasSimklCredentials = true
        snapshot.hasOpenSubtitlesKey = true
        snapshot.environmentAssetCount = 1
        snapshot.hasOllamaEndpoint = false
        snapshot.isLocalAIEnabled = false
        snapshot.hasUsableLocalModel = false

        #expect(RootNavigationBadgePolicy.settingsWarningCount(from: snapshot) == 1)
    }

    @Test
    func settingsWarningCountIsZeroForFullyConfiguredSnapshot() {
        var snapshot = SettingsStatusSnapshot()
        snapshot.activeDebridCount = 2
        snapshot.activeIndexerCount = 3
        snapshot.hasTMDBKey = true
        snapshot.aiProvider = .openAI
        snapshot.hasOpenAIKey = true
        snapshot.hasOllamaEndpoint = false
        snapshot.hasTraktCredentials = true
        snapshot.hasTraktConnection = true
        snapshot.hasOpenSubtitlesKey = true
        snapshot.environmentAssetCount = 1

        #expect(RootNavigationBadgePolicy.settingsWarningCount(from: snapshot) == 0)
    }
}
