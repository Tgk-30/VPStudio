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
        #expect(source.contains("let latestEnvironments = try await appState.environmentCatalogManager.fetchAssets()"))
        #expect(source.contains("appState.reconcileEnvironmentSelection(withLoadedAssets: latestEnvironments)"))
        #expect(source.contains("importError = nil"))
        #expect(source.contains("importError = EnvironmentErrorPresentationPolicy.displayMessage(for: error)"))
        #expect(!source.contains("let latestEnvironments = (try? await appState.environmentCatalogManager.fetchAssets()) ?? []"))
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
        #expect(source.contains("appState.reconcileEnvironmentSelection(withLoadedAssets: latestAssets)"))
        #expect(source.contains(".onDisappear"))
        #expect(source.contains("assetLoadTask = nil"))
    }

    @Test
    func environmentsTabReconcilesLoadedAssetsAndDoesNotSilentlyEmptyOnFailure() throws {
        let source = try contents(of: "VPStudio/Views/Windows/ContentView.swift")
        let body = try section(
            from: "private func loadEnvironments() async {",
            to: "    private func isPresetInstalled",
            in: source
        )

        #expect(body.contains("let latestEnvironments = try await appState.environmentCatalogManager.fetchAssets()"))
        #expect(body.contains("environments = latestEnvironments"))
        #expect(body.contains("appState.reconcileEnvironmentSelection(withLoadedAssets: latestEnvironments)"))
        #expect(body.contains("environmentError = nil"))
        #expect(body.contains("environmentError = EnvironmentErrorPresentationPolicy.displayMessage(for: error)"))
        #expect(!body.contains("(try? await appState.environmentCatalogManager.fetchAssets()) ?? []"))
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
        #expect(settingsSource.contains("Text(\"Built-in\")"))
    }

    @Test
    func contentViewDoesNotOpenImmersiveSpaceAfterEnvironmentActivationFails() throws {
        let source = try contents(of: "VPStudio/Views/Windows/ContentView.swift")

        #expect(source.contains("guard await appState.activateEnvironmentAsset(asset) else {"))
        #expect(source.contains("PlayerImmersiveTransitionPolicy.missingAssetMessage(assetName: asset.name)"))
        #expect(source.contains("let spaceID = await appState.environmentCatalogManager.immersiveSpaceID(for: asset)"))
    }

    @Test
    func nonPlayerEnvironmentSurfacesValidateAssetsBeforeActivation() throws {
        let contentSource = try contents(of: "VPStudio/Views/Windows/ContentView.swift")
        let settingsSource = try contents(of: "VPStudio/Views/Windows/Settings/Destinations/EnvironmentSettingsView.swift")

        for source in [contentSource, settingsSource] {
            #expect(source.contains("private func ensureEnvironmentAssetExists(_ asset: EnvironmentAsset) async -> Bool"))
            #expect(!source.contains("guard asset.sourceType == .imported else { return true }"))
            #expect(source.contains("resolvedAssetURL(for: asset)"))
            #expect(source.contains("if asset.sourceType == .imported {"))
            #expect(source.contains("try? await appState.environmentCatalogManager.deleteAsset(id: asset.id)"))
            #expect(source.contains("clearEnvironmentSelectionIfCurrent(assetID: asset.id)"))
            #expect(source.contains("return false"))
        }
        #expect(contentSource.contains("guard await ensureEnvironmentAssetExists(asset) else {"))
        #expect(settingsSource.contains("guard await ensureEnvironmentAssetExists(asset) else {"))
    }

    @Test
    func nonPlayerEnvironmentSurfacesFailClosedForMissingBundledAssets() throws {
        let surfacePaths = [
            "VPStudio/Views/Windows/ContentView.swift",
            "VPStudio/Views/Windows/Settings/Destinations/EnvironmentSettingsView.swift",
        ]

        for path in surfacePaths {
            let source = try contents(of: path)
            let normalized = source.components(separatedBy: .whitespacesAndNewlines).joined()
            #expect(normalized.contains("ifawaitappState.environmentCatalogManager.resolvedAssetURL(for:asset)!=nil{returntrue}"))
            #expect(normalized.contains("ifasset.sourceType==.imported{try?awaitappState.environmentCatalogManager.deleteAsset(id:asset.id)"))
            #expect(normalized.contains("}returnfalse}"))
        }
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
        #expect(source.contains("Use Apple Environment"))
        #expect(source.contains("EnvironmentPreviewRowPolicy.appleEnvironmentSelectedTitle"))
        #expect(source.contains("EnvironmentPreviewRowPolicy.appleEnvironmentSelectedBody"))
        #expect(!source.contains("private var environmentStatusBadgeText: String"))
        #expect(source.contains("Task { await installPreset(preset) }"))
        #expect(source.contains("Text(\"Adding\")"))
        #expect(source.contains("Label(\"Added\", systemImage: \"checkmark.circle.fill\")"))
        #expect(source.contains("Label(\"Activate\", systemImage: \"play.circle\")"))
        #expect(source.contains("Task { await selectEnvironment(installedAsset) }"))
        #expect(source.contains("environmentErrorBanner(environmentError)"))
        #expect(source.contains("Button(\"Dismiss\") { environmentError = nil }"))
        #expect(source.contains("Text(\"Add a curated environment below, or import your own files from Settings.\")"))
        #expect(normalized.contains("guard!isPresetInstalled(preset),!installingPresetIDs.contains(preset.id)else{return}"))
        #expect(normalized.contains("environmentError=EnvironmentErrorPresentationPolicy.displayMessage(for:error)"))
        #expect(!normalized.contains("environmentError=error.localizedDescription"))
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

    private func section(from startToken: String, to endToken: String, in source: String) throws -> String {
        let start = try #require(source.range(of: startToken))
        let end = try #require(source.range(of: endToken, range: start.upperBound..<source.endIndex))
        return String(source[start.lowerBound..<end.lowerBound])
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
