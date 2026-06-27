import Foundation
import Testing
@testable import VPStudio

@Suite("Environment Loader Task Lifecycle")
struct EnvironmentLoaderTaskLifecycleTests {
    @Test
    func environmentsTabViewCoalescesNotificationDrivenLoadsAndCancelsOnDisappear() throws {
        let source = try contents(of: "VPStudio/Views/Windows/ContentView.swift")
        #expect(source.contains("@State private var environmentLoadTask: Task<Void, Never>?"))
        #expect(source.contains("guard !disablesAutomaticTasks else { return }"))
        #expect(source.contains("await coalescedLoadEnvironments()"))
        #expect(source.contains(".onReceive(NotificationCenter.default.publisher(for: .environmentsDidChange))"))
        #expect(source.contains("environmentLoadTask?.cancel()"))
        #expect(source.contains("environmentLoadTask = Task { await loadEnvironments() }"))
        #expect(source.contains(".onDisappear"))
        #expect(source.contains("environmentLoadTask = nil"))
    }

    @Test
    func environmentPickerSheetCoalescesNotificationDrivenLoadsAndCancelsOnDisappear() throws {
        let source = try contents(of: "VPStudio/Views/Windows/Discover/EnvironmentPreviewRow.swift")
        #expect(source.contains("@State private var environmentLoadTask: Task<Void, Never>?"))
        #expect(source.contains("static let bottomContentPadding: CGFloat"))
        #expect(source.contains(".padding(.bottom, EnvironmentPreviewLayoutPolicy.bottomContentPadding)"))
        #expect(source.contains("guard !disablesAutomaticTasks else { return }"))
        #expect(source.contains("await coalescedLoadEnvironments()"))
        #expect(source.contains(".onReceive(NotificationCenter.default.publisher(for: .environmentsDidChange))"))
        #expect(source.contains("environmentLoadTask?.cancel()"))
        #expect(source.contains("environmentLoadTask = Task { await loadEnvironments() }"))
        #expect(source.contains(".onDisappear"))
        #expect(source.contains("environmentLoadTask = nil"))
    }

    @Test
    func environmentSettingsViewCoalescesNotificationDrivenLoadsAndCancelsOnDisappear() throws {
        let source = try contents(of: "VPStudio/Views/Windows/Settings/Destinations/EnvironmentSettingsView.swift")
        #expect(source.contains("@State private var assetLoadTask: Task<Void, Never>?"))
        #expect(source.contains("await coalescedLoadAssets()"))
        #expect(source.contains(".onReceive(NotificationCenter.default.publisher(for: .environmentsDidChange))"))
        #expect(source.contains("assetLoadTask?.cancel()"))
        #expect(source.contains("assetLoadTask = Task { await loadAssets() }"))
        #expect(source.contains(".onDisappear"))
        #expect(source.contains("assetLoadTask = nil"))
    }

    @Test
    func builtInCinemaEnvironmentIsVisibleInSharedPickerEvenWithoutImportedAssets() throws {
        let source = try contents(of: "VPStudio/Views/Windows/Discover/EnvironmentPreviewRow.swift")

        #expect(source.contains("var onSelectCinema: (() -> Void)? = nil"))
        #expect(source.contains("CinemaEnvironmentPreviewCard("))
        #expect(source.contains("Text(\"Cinema Environment\")"))
        #expect(source.contains("Text(\"No imported environments\")"))
        #expect(source.contains("Text(\"No Environments\")") == false)
    }

    @Test
    func playerEnvironmentPickerPassesCinemaOpenAction() throws {
        let source = try contents(of: "VPStudio/Views/Windows/Player/PlayerView.swift")

        #expect(source.contains("onSelectCinema: {"))
        #expect(source.contains("openCinemaEnvironmentAfterMenuDismissal()"))
    }

    @Test
    func mainEnvironmentSurfacesExposeBuiltInCinemaEnvironment() throws {
        let contentSource = try contents(of: "VPStudio/Views/Windows/ContentView.swift")
        let settingsSource = try contents(of: "VPStudio/Views/Windows/Settings/Destinations/EnvironmentSettingsView.swift")

        #expect(contentSource.contains("CinemaEnvironmentPreviewCard("))
        #expect(contentSource.contains("selectCinemaEnvironment()"))
        #expect(contentSource.contains("openImmersiveSpace(id: EnvironmentType.cinemaEnvironment.immersiveSpaceId)"))
        #expect(settingsSource.contains("builtInCinemaRow"))
        #expect(settingsSource.contains("Text(\"Cinema Environment\")"))
        #expect(settingsSource.contains("Text(\"Built-In\")"))
    }

    @Test
    func contentViewDoesNotOpenImmersiveSpaceAfterEnvironmentActivationFails() throws {
        let source = try contents(of: "VPStudio/Views/Windows/ContentView.swift")

        #expect(source.contains("guard await appState.activateEnvironmentAsset(asset) else {"))
        #expect(source.contains("PlayerImmersiveTransitionPolicy.missingAssetMessage(assetName: asset.name)"))
        #expect(source.contains("let spaceID = await appState.environmentCatalogManager.immersiveSpaceID(for: asset)"))
    }

    @Test
    func nonPlayerEnvironmentSurfacesDeleteMissingImportedAssetsBeforeActivation() throws {
        let contentSource = try contents(of: "VPStudio/Views/Windows/ContentView.swift")
        let settingsSource = try contents(of: "VPStudio/Views/Windows/Settings/Destinations/EnvironmentSettingsView.swift")

        for source in [contentSource, settingsSource] {
            #expect(source.contains("private func ensureImportedEnvironmentAssetExists(_ asset: EnvironmentAsset) async -> Bool"))
            #expect(source.contains("guard asset.sourceType == .imported else { return true }"))
            #expect(source.contains("resolvedAssetURL(for: asset)"))
            #expect(source.contains("deleteAsset(id: asset.id)"))
            #expect(source.contains("clearEnvironmentSelectionIfCurrent(assetID: asset.id)"))
        }
        #expect(contentSource.contains("guard await ensureImportedEnvironmentAssetExists(asset) else {"))
        #expect(settingsSource.contains("guard await ensureImportedEnvironmentAssetExists(asset) else {"))
    }

    @Test
    func nonPlayerEnvironmentSurfacesDoNotMutateSelectionWhenTransitionBusy() throws {
        let source = try contents(of: "VPStudio/Views/Windows/ContentView.swift")
        let normalized = source.components(separatedBy: .whitespacesAndNewlines).joined()

        #expect(source.contains("@State private var environmentPickerError: String?"))
        #expect(source.contains("PlayerImmersiveTransitionPolicy.transitionBusyMessage"))
        #expect(source.contains("private func dismissEnvironmentIfNeeded(reason: ImmersiveDismissReason) async -> Bool"))
        #expect(source.contains("private func exitEnvironment() async -> Bool"))
        #expect(normalized.contains("guardawaitdismissEnvironmentIfNeeded(reason:.switchingEnvironment)else{environmentPickerError=PlayerImmersiveTransitionPolicy.transitionBusyMessagereturn}"))
        #expect(normalized.contains("guardawaitexitEnvironment()else{environmentError=PlayerImmersiveTransitionPolicy.transitionBusyMessagereturn}"))
        #expect(normalized.contains("guardappState.beginImmersiveTransition()else{awaitappState.clearEnvironmentSelectionIfCurrent(assetID:asset.id)environmentPickerError=PlayerImmersiveTransitionPolicy.transitionBusyMessagereturn}"))
        #expect(normalized.contains("guardappState.beginImmersiveTransition()else{awaitappState.clearEnvironmentSelectionIfCurrent(assetID:asset.id)environmentError=PlayerImmersiveTransitionPolicy.transitionBusyMessageawaitcoalescedLoadEnvironments()return}"))
    }

    @Test
    func contentViewRollsBackEnvironmentSelectionAfterOpenFailure() throws {
        let source = try contents(of: "VPStudio/Views/Windows/ContentView.swift")
        let normalized = source.components(separatedBy: .whitespacesAndNewlines).joined()

        #expect(normalized.contains("case.error,.userCancelled:appState.cancelImmersiveTransition()awaitappState.clearEnvironmentSelectionIfCurrent(assetID:asset.id)"))
        #expect(normalized.contains("@unknowndefault:appState.cancelImmersiveTransition()awaitappState.clearEnvironmentSelectionIfCurrent(assetID:asset.id)"))
        #expect(source.contains("environmentError = PlayerImmersiveTransitionPolicy.openFailedMessage(assetName: asset.name)"))
    }

    @Test
    func nonPlayerEnvironmentDismissalsCompletePendingTransitionState() throws {
        let environmentSurfacePaths = [
            "VPStudio/Views/Windows/ContentView.swift",
            "VPStudio/Views/Windows/Settings/Destinations/EnvironmentSettingsView.swift",
            "VPStudio/Views/Windows/Discover/EnvironmentPreviewRow.swift",
        ]

        for path in environmentSurfacePaths {
            let source = try contents(of: path)
            #expect(
                dismissImmersiveCallsAreImmediatelyCompleted(in: source),
                "\(path) must complete pending AppState transition state after dismissImmersiveSpace()."
            )
        }
    }

    @Test
    func environmentsTabExposesCuratedPresetInstallRecovery() throws {
        let source = try contents(of: "VPStudio/Views/Windows/ContentView.swift")
        let normalized = source.components(separatedBy: .whitespacesAndNewlines).joined()

        #expect(source.contains("private let onlinePresets = EnvironmentCatalogManager.onlinePresets"))
        #expect(source.contains("@State private var installingPresetIDs: Set<String> = []"))
        #expect(source.contains("@State private var environmentError: String?"))
        #expect(source.contains("onlinePresetsSection"))
        #expect(source.contains("Text(\"More Environments\")"))
        #expect(source.contains("ForEach(onlinePresets) { preset in"))
        #expect(source.contains(".padding(.bottom, EnvironmentPreviewLayoutPolicy.bottomContentPadding)"))
        #expect(source.contains("Use Standard Room"))
        #expect(source.contains("No immersive room selected"))
        #expect(source.contains("Playback will stay in the standard windowed room."))
        #expect(source.contains("return \"Windowed\""))
        #expect(source.contains("Task { await installPreset(preset) }"))
        #expect(source.contains("Text(\"Adding\")"))
        #expect(source.contains("Label(\"Added\", systemImage: \"checkmark.circle.fill\")"))
        #expect(source.contains("environmentErrorBanner(environmentError)"))
        #expect(source.contains("Button(\"Dismiss\") { environmentError = nil }"))
        #expect(source.contains("Text(\"Add a curated room below, or import your own files from Settings.\")"))
        #expect(normalized.contains("guard!isPresetInstalled(preset),!installingPresetIDs.contains(preset.id)else{return}"))
        #expect(normalized.contains("environmentError=error.localizedDescription"))
    }

    private func dismissImmersiveCallsAreImmediatelyCompleted(in source: String) -> Bool {
        let lines = source.components(separatedBy: .newlines)
        for index in lines.indices where lines[index].contains("await dismissImmersiveSpace()") {
            guard let nextCodeLine = lines[(index + 1)...].first(where: { line in
                let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
                return !trimmed.isEmpty && !trimmed.hasPrefix("//")
            }) else {
                return false
            }
            if !nextCodeLine.contains("appState.completeImmersiveDismissIfStillPending()") {
                return false
            }
        }
        return true
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
