import Foundation
import Testing
@testable import VPStudio

@Suite("Loading Surface Policies")
struct LoadingSurfacePolicyTests {
    @Test
    func libraryLoadingPolicyTracksSelectionReloads() {
        #expect(LibraryLoadingSurfacePolicy.shouldShowLoadingSurface(isLoadingSelection: true))
        #expect(LibraryLoadingSurfacePolicy.shouldShowLoadingSurface(isLoadingSelection: false) == false)
        #expect(LibraryLoadingSurfacePolicy.title == "Loading Library")
        #expect(LibraryLoadingSurfacePolicy.message == "Fetching watchlist, favorites, and history.")
    }

    @Test
    func downloadsLoadingPolicyShowsRootLoaderBeforeViewModelExists() {
        #expect(
            DownloadsLoadingSurfacePolicy.shouldShowRootLoading(
                hasViewModel: false,
                isLoading: false,
                groupCount: 0
            )
        )
    }

    @Test
    func downloadsLoadingPolicyShowsRootLoaderDuringInitialEmptyLoad() {
        #expect(
            DownloadsLoadingSurfacePolicy.shouldShowRootLoading(
                hasViewModel: true,
                isLoading: true,
                groupCount: 0
            )
        )
    }

    @Test
    func downloadsLoadingPolicyKeepsContentWhenGroupsAlreadyExist() {
        #expect(
            DownloadsLoadingSurfacePolicy.shouldShowRootLoading(
                hasViewModel: true,
                isLoading: true,
                groupCount: 3
            ) == false
        )

        #expect(
            DownloadsLoadingSurfacePolicy.shouldShowRootLoading(
                hasViewModel: true,
                isLoading: false,
                groupCount: 0
            ) == false
        )
    }
}

@Suite("Loading Surface Contracts")
struct LoadingSurfaceContractTests {
    @Test
    func contentViewLaunchScreenIsBoundToBootstrapping() throws {
        let source = try contents(of: "VPStudio/Views/Windows/ContentView.swift")
        #expect(source.contains("RootLaunchOverlayPolicy.shouldShowLaunchOverlay"))
        #expect(source.contains("isBootstrapping: appState.isBootstrapping"))
        #expect(source.contains("LaunchScreen()"))
    }

    @Test
    func contentViewSuppressesBootstrappingForQATestScreens() throws {
        let source = try contents(of: "VPStudio/Views/Windows/ContentView.swift")
        #expect(source.contains("presentQATestScreenIfRequested()"))
        #expect(source.contains("appState.isBootstrapping = false"))
    }

    @Test
    func downloadsViewUsesSharedLoadingOverlayInsteadOfRawProgressView() throws {
        let source = try contents(of: "VPStudio/Views/Windows/Downloads/DownloadsView.swift")
        #expect(source.contains("DownloadsLoadingSurfacePolicy.shouldShowRootLoading"))
        #expect(source.contains("LoadingOverlay("))
        #expect(source.contains("ProgressView(\"Loading Downloads...\")") == false)
    }

    @Test
    func downloadsViewGatesCompletedFilePlaybackWithPlayerLaunchabilityPolicy() throws {
        let source = try contents(of: "VPStudio/Views/Windows/Downloads/DownloadsView.swift")
        let start = try #require(source.range(of: "private func playDownload"))
        let end = try #require(source.range(of: "let request = PlayerSessionRequest", range: start.upperBound..<source.endIndex))
        let playDownloadSetup = String(source[start.lowerBound..<end.lowerBound])

        #expect(playDownloadSetup.contains("PlayerStreamURLPolicy.isLaunchable(stream)"))
        #expect(!playDownloadSetup.contains("fileExists(atPath: fileURL.path)"))
    }

    @Test
    func environmentPreviewRowGatesThumbnailDecodeWithRegularFilePolicy() throws {
        let source = try contents(of: "VPStudio/Views/Windows/Discover/EnvironmentPreviewRow.swift")
        let loadStart = try #require(source.range(of: "private func loadThumbnail()"))
        let loadEnd = try #require(source.range(
            of: "let image = await withTaskCancellationHandler",
            range: loadStart.upperBound..<source.endIndex
        ))
        let loadSetup = String(source[loadStart.lowerBound..<loadEnd.lowerBound])
        let policyStart = try #require(source.range(of: "static func isReadableThumbnailFile"))
        let policyEnd = try #require(source.range(
            of: "static func shouldClearActiveSelection",
            range: policyStart.upperBound..<source.endIndex
        ))
        let policyBody = String(source[policyStart.lowerBound..<policyEnd.lowerBound])

        #expect(loadSetup.contains("EnvironmentPreviewRowPolicy.isReadableThumbnailFile(url)"))
        #expect(!loadSetup.contains("fileExists(atPath: url.path)"))
        #expect(policyBody.contains(".isRegularFileKey"))
        #expect(policyBody.contains(".isSymbolicLinkKey"))
        #expect(policyBody.contains(".isDirectoryKey"))
        #expect(policyBody.contains("values.isRegularFile == true"))
        #expect(policyBody.contains("values.isSymbolicLink != true"))
        #expect(policyBody.contains("values.isDirectory != true"))
    }

    @Test
    func libraryViewUsesDedicatedSelectionLoadingSurface() throws {
        let source = try contents(of: "VPStudio/Views/Windows/Library/LibraryView.swift")
        #expect(source.contains("@State private var isLoadingSelection = true"))
        #expect(source.contains("@State private var selectionLoadToken = 0"))
        #expect(source.contains("LibraryLoadingSurfacePolicy.shouldShowLoadingSurface"))
        #expect(source.contains("LoadingOverlay("))
        #expect(source.contains("selectionLoadToken += 1"))
        #expect(source.contains("isLoadingSelection = true"))
    }

    private func contents(of relativePath: String) throws -> String {
        let absolutePath = repoRootURL().appendingPathComponent(relativePath).path
        return try String(contentsOfFile: absolutePath, encoding: .utf8)
    }

    private func repoRootURL() -> URL {
        var url = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
        while !FileManager.default.fileExists(atPath: url.appendingPathComponent("Package.swift").path) {
            let parent = url.deletingLastPathComponent()
            if parent.path == url.path { break }
            url = parent
        }
        return url
    }
}
