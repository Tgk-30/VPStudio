#if os(visionOS)
import Foundation
import Testing
@testable import VPStudio

@Suite("Environment Immersive Coverage")
struct EnvironmentImmersiveCoverageTests {
    @Test
    func screenSizePresetCoversDimensionsCycleAndSubtitleOffsets() {
        #expect(ScreenSizePreset.personal.rawValue == "Personal")
        #expect(ScreenSizePreset.personal.width == 6)
        #expect(ScreenSizePreset.personal.height == 3.375)
        #expect(ScreenSizePreset.personal.distance == 10)

        #expect(ScreenSizePreset.cinema.rawValue == "Cinema")
        #expect(ScreenSizePreset.cinema.width == 10)
        #expect(ScreenSizePreset.cinema.height == 5.625)
        #expect(ScreenSizePreset.cinema.distance == 20)

        #expect(ScreenSizePreset.imax.rawValue == "IMAX")
        #expect(ScreenSizePreset.imax.width == 16)
        #expect(ScreenSizePreset.imax.height == 9)
        #expect(ScreenSizePreset.imax.distance == 35)

        #expect(ScreenSizePreset.personal.next == .cinema)
        #expect(ScreenSizePreset.cinema.next == .imax)
        #expect(ScreenSizePreset.imax.next == .personal)

        #expect(ScreenSizePreset.personal.subtitleVerticalOffset > 0)
        #expect(ScreenSizePreset.cinema.subtitleMaxWidth > ScreenSizePreset.personal.subtitleMaxWidth)
        #expect(ScreenSizePreset.imax.subtitleFontSize >= ScreenSizePreset.cinema.subtitleFontSize)
    }

    @Test
    func hdriSkyboxSourceRetainsFallbackLoadingAndLifecycleBranches() throws {
        let source = try sourceContents(of: "VPStudio/Views/Immersive/HDRISkyboxEnvironment.swift")

        #expect(source.contains("placeholder.name = \"hdri-placeholder\""))
        #expect(source.contains("screen.name = \"cinema-screen\""))
        #expect(source.contains("tapCatcher.name = \"tap-catcher\""))
        #expect(source.contains("renderState.tapCatcher = tapCatcher"))
        #expect(source.contains("updateTapCatcher(tapCatcher, for: screen"))
        #expect(source.contains("ImmersiveControlsPolicy.tapCatcherPosition(forScreenPosition: screen.position)"))
        #expect(!source.contains("ShapeResource.generateBox(size: [200, 200, 0.5])"))
        #expect(!source.contains("tapCatcher.position = SIMD3<Float>(0, 0, -5)"))
        #expect(source.contains("anchor.name = \"controls-anchor\""))
        #expect(source.contains("setLoadingState(.failed(HDRISkyboxFailureCopy.noEnvironmentSelected))"))
        #expect(source.contains("setLoadingState(.failed(HDRISkyboxFailureCopy.missingEnvironmentFile))"))
        #expect(source.contains("setLoadingState(.failed(HDRISkyboxFailureCopy.decodeFailure))"))
        #expect(source.contains("setLoadingState(.failed(HDRISkyboxFailureCopy.resourceFailure))"))
        #expect(source.contains("Text(\"Exit Environment\")"))
        #expect(!source.contains("Text(\"Close\")"))
        #expect(source.contains("HDRI environment resource creation failed"))
        #expect(source.contains("IndexerLogSanitizer.redactedErrorMessage(error)"))
        #expect(!source.contains("HDRI environment resource creation failed: \\(error.localizedDescription"))
        #expect(!source.contains("setLoadingState(.failed(error.localizedDescription))"))
        #expect(source.contains("TextureResource("))
        #expect(source.contains("EnvironmentResource(equirectangular: cgImage)"))
        #expect(!source.contains("loadingPanel.removeFromParent()"))
        #expect(source.contains("appState.immersiveSpaceDidAppear(.hdriSkybox)"))
        #expect(source.contains("appState.immersiveSpaceDidDisappear()"))
        #expect(source.contains("renderState.reset()"))
        #expect(source.contains("var hdriLoadTask: Task<CGImage?, Never>?"))
        #expect(source.contains("func beginEnvironmentLoad(assetID: String) -> UUID"))
        #expect(source.contains("func isCurrentEnvironmentLoad(_ loadID: UUID, assetID: String) -> Bool"))
        #expect(source.contains("hdriLoadTask?.cancel()"))
        #expect(source.contains("renderState.setHDRILoadTask(hdriLoadTask, for: environmentLoadID)"))
        #expect(source.contains("guard renderState.isCurrentEnvironmentLoad(environmentLoadID, assetID: asset.id) else { return }"))
        #expect(source.contains("@MainActor\n    private func setLoadingState(_ state: LoadingState)"))
        #expect(!source.contains("Task { @MainActor in\n            loadingState = state"))
        #expect(source.contains(".id(appState.selectedEnvironmentAsset?.id ?? \"no-environment\")"))
    }

    @Test
    func hdriSkyboxFailureCopyExplainsPlainScreenFallback() {
        for message in [
            HDRISkyboxFailureCopy.noEnvironmentSelected,
            HDRISkyboxFailureCopy.missingEnvironmentFile,
            HDRISkyboxFailureCopy.decodeFailure,
            HDRISkyboxFailureCopy.resourceFailure,
        ] {
            #expect(message.contains("Playing on a plain screen."))
        }
    }

    @Test
    func hdriSkyboxCrossfadesLoadedSkyOverPlaceholder() throws {
        let source = try sourceContents(of: "VPStudio/Views/Immersive/HDRISkyboxEnvironment.swift")

        #expect(HDRISkyboxTransitionPolicy.fadeStepCount == 8)
        #expect(HDRISkyboxTransitionPolicy.fadeStepDelayNanoseconds > 0)
        #expect(HDRISkyboxTransitionPolicy.fadeProgress(step: 0) == 0)
        #expect(HDRISkyboxTransitionPolicy.fadeProgress(step: HDRISkyboxTransitionPolicy.fadeStepCount) == 1)
        #expect(HDRISkyboxTransitionPolicy.fadeProgress(step: HDRISkyboxTransitionPolicy.fadeStepCount + 1) == 1)

        #expect(source.contains("placeholder.components[OpacityComponent.self] = OpacityComponent(opacity: 1.0)"))
        #expect(source.contains("skyEntity.components[OpacityComponent.self] = OpacityComponent(opacity: 0.0)"))
        #expect(source.contains("await crossfadeSkybox("))
        #expect(source.contains("private func crossfadeSkybox("))
        #expect(source.contains("guard !accessibilityReduceMotion else"))
        #expect(source.contains("applyOpacity(skyEntity, progress)"))
        #expect(source.contains("applyOpacity(placeholder, max(0, 1 - progress))"))
        #expect(source.contains("placeholder.removeFromParent()"))
    }

    @Test
    func customEnvironmentSourceRetainsFallbackScreenAndScreenDiscoveryBranches() throws {
        let source = try sourceContents(of: "VPStudio/Views/Immersive/CustomEnvironmentView.swift")

        #expect(source.contains("guard let selected = appState.selectedEnvironmentAsset else"))
        #expect(source.contains("func beginEnvironmentLoad(assetID: String) -> UUID"))
        #expect(source.contains("func isCurrentEnvironmentLoad(_ loadID: UUID, assetID: String) -> Bool"))
        #expect(source.contains("func cancelEnvironmentLoad()"))
        #expect(source.contains("let environmentLoadID = renderState.beginEnvironmentLoad(assetID: selected.id)"))
        #expect(source.contains("guard renderState.isCurrentEnvironmentLoad(environmentLoadID, assetID: selected.id) else { return }"))
        #expect(source.contains("renderState.cancelEnvironmentLoad()"))
        #expect(source.contains("lastMaterialSourceID = nil"))
        #expect(!source.contains("private func isCurrentSelection(_ assetID: String) -> Bool"))
        #expect(source.contains(".id(appState.selectedEnvironmentAsset?.id ?? \"no-environment\")"))
        #expect(source.contains("setLoadingState(.failed(CustomEnvironmentFailureCopy.noEnvironmentSelected))"))
        #expect(source.contains("setLoadingState(.failed(CustomEnvironmentFailureCopy.missingEnvironmentFile))"))
        #expect(source.contains("setLoadingState(.failed(CustomEnvironmentFailureCopy.missingScreenSurface))"))
        #expect(source.contains("setLoadingState(.failed(CustomEnvironmentFailureCopy.resourceFailure))"))
        #expect(source.contains("IndexerLogSanitizer.redactedErrorMessage(error)"))
        #expect(!source.contains("Entity(contentsOf:) failed — \\(error.localizedDescription"))
        #expect(source.contains("Text(\"Exit Environment\")"))
        #expect(!source.contains("Showing a fallback screen."))
        #expect(source.contains("@MainActor\n    private func setLoadingState(_ state: LoadingState)"))
        #expect(!source.contains("Task { @MainActor in\n            loadingState = state"))
        #expect(source.contains("let keywords = [\"screen\", \"display\", \"tv\", \"monitor\", \"cinema\", \"video\"]"))
        #expect(source.contains("keywords.contains(where: { lowerName.containsStandaloneToken($0) })"))
        #expect(source.contains("screen.name = \"custom-fallback-screen\""))
        #expect(!source.contains("loadingPanel.removeFromParent()"))
        #expect(source.contains("ImmersivePlayerControlsView(showsScreenSizeControl: false)"))
        #expect(source.contains("appState.immersiveSpaceDidAppear(.customEnvironment)"))
        #expect(source.contains("appState.immersiveSpaceDidDisappear()"))
    }

    @Test
    func customEnvironmentFailureCopyExplainsPlainScreenFallback() {
        for message in [
            CustomEnvironmentFailureCopy.noEnvironmentSelected,
            CustomEnvironmentFailureCopy.missingEnvironmentFile,
            CustomEnvironmentFailureCopy.missingScreenSurface,
            CustomEnvironmentFailureCopy.resourceFailure,
        ] {
            #expect(message.contains("Playing on a plain screen."))
            #expect(!message.contains("fallback screen"))
        }
    }

    @Test
    func immersiveEnvironmentsResetControlAutoDismissForEveryControlNotification() throws {
        let hdriSource = try sourceContents(of: "VPStudio/Views/Immersive/HDRISkyboxEnvironment.swift")
        let customSource = try sourceContents(of: "VPStudio/Views/Immersive/CustomEnvironmentView.swift")

        for notificationName in [
            ".immersiveTapCatcherDidFire",
            ".immersiveControlTogglePlayPause",
            ".immersiveControlSeekBack",
            ".immersiveControlSeekForward",
            ".immersiveControlSeekToPercent"
        ] {
            #expect(hdriSource.contains(notificationName), "HDRI should observe \(notificationName)")
            #expect(customSource.contains(notificationName), "Custom environments should observe \(notificationName)")
        }

        #expect(hdriSource.contains("cycleScreenSize()"))
        #expect(customSource.contains("// Custom USDZ environments have a fixed screen mesh"))
        #expect(hdriSource.contains("try? await Task.sleep(for: ImmersiveControlsPolicy.autoDismissInterval)"))
        #expect(customSource.contains("try? await Task.sleep(for: ImmersiveControlsPolicy.autoDismissInterval)"))
        #expect(hdriSource.contains("headTracker.isIdle = true"))
        #expect(customSource.contains("headTracker.isIdle = true"))
    }

    @Test
    func cinemaImmersiveMaterialLogsRedactRawErrorDescriptions() throws {
        let source = try sourceContents(of: "VPStudio/Views/Immersive/Cinema/CinemaImmersiveContent.swift")

        #expect(source.contains("IndexerLogSanitizer.redactedErrorMessage(error)"))
        #expect(!source.contains("VideoMaterial creation failed: \\(error.localizedDescription"))
    }
}

private func sourceContents(of relativePath: String) throws -> String {
    let root = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
    return try String(contentsOf: root.appendingPathComponent(relativePath), encoding: .utf8)
}
#endif
