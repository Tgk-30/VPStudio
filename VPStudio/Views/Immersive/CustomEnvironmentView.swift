#if os(visionOS)
import os
import Foundation
import SwiftUI
import RealityKit

private let logger = Logger(subsystem: "com.vpstudio.app", category: "CustomEnvironment")

enum CustomEnvironmentFailureCopy {
    static let noEnvironmentSelected = "No environment selected. Playing on a plain screen."
    static let missingEnvironmentFile = "The selected environment file is missing. Playing on a plain screen."
    static let missingScreenSurface = "No screen surface was found in this environment. Playing on a plain screen."
    static let resourceFailure = "The environment failed to load. Playing on a plain screen."
}

private final class CustomEnvironmentRenderState {
    var cinemaScreen: ModelEntity?
    var controlsAnchor: Entity?
    var tapCatcher: Entity?
    var lastMaterialSourceID: ObjectIdentifier?
    var subtitleEntity: Entity?
    var autoDismissTask: Task<Void, Never>?
    var activeEnvironmentAssetID: String?
    var activeEnvironmentLoadID: UUID?

    func beginEnvironmentLoad(assetID: String) -> UUID {
        let loadID = UUID()
        activeEnvironmentAssetID = assetID
        activeEnvironmentLoadID = loadID
        cinemaScreen = nil
        subtitleEntity = nil
        lastMaterialSourceID = nil
        return loadID
    }

    func isCurrentEnvironmentLoad(_ loadID: UUID, assetID: String) -> Bool {
        activeEnvironmentLoadID == loadID && activeEnvironmentAssetID == assetID
    }

    func cancelEnvironmentLoad() {
        activeEnvironmentAssetID = nil
        activeEnvironmentLoadID = nil
        cinemaScreen = nil
        subtitleEntity = nil
        lastMaterialSourceID = nil
    }

    func reset() {
        autoDismissTask?.cancel()
        autoDismissTask = nil
        cinemaScreen = nil
        controlsAnchor = nil
        tapCatcher = nil
        subtitleEntity = nil
        lastMaterialSourceID = nil
        activeEnvironmentAssetID = nil
        activeEnvironmentLoadID = nil
    }
}

struct CustomEnvironmentView: View {
    @Environment(AppState.self) private var appState
    @Environment(VPPlayerEngine.self) private var engine
    @Environment(\.accessibilityReduceMotion) private var accessibilityReduceMotion

    @State private var headTracker = HeadTracker()
    @State private var isShowingImmersiveControls = false
    @State private var renderState = CustomEnvironmentRenderState()
    @State private var loadingState: LoadingState = .loading
    @State private var subtitleFontSize: Double = 24

    enum LoadingState: Equatable {
        case loading
        case loaded
        case failed(String)
    }

    var body: some View {
        RealityView { content, attachments in
            setLoadingState(.loading)

            // MARK: TapCatcher
            let tapCatcher = Entity()
            tapCatcher.name = "tap-catcher"
            tapCatcher.components.set(InputTargetComponent(allowedInputTypes: .indirect))
            updateTapCatcher(
                tapCatcher,
                screenPosition: SIMD3<Float>(0, ImmersiveControlsPolicy.fallbackEyeHeight, -4),
                screenOrientation: simd_quatf(),
                width: ScreenSizePreset.personal.width,
                height: ScreenSizePreset.personal.height
            )
            content.add(tapCatcher)
            renderState.tapCatcher = tapCatcher

            // MARK: Controls anchor
            let anchor = Entity()
            anchor.name = "controls-anchor"
            content.add(anchor)
            renderState.controlsAnchor = anchor

            if let controlsPanel = attachments.entity(for: "playerControls") {
                controlsPanel.position = SIMD3<Float>(0, -0.15, -1.5)
                anchor.addChild(controlsPanel)
            }

            if let loadingPanel = attachments.entity(for: "loadingIndicator") {
                loadingPanel.position = SIMD3<Float>(0, 1.6, -4)
                content.add(loadingPanel)
            }

            guard let selected = appState.selectedEnvironmentAsset else {
                renderState.cancelEnvironmentLoad()
                logger.warning("No selectedEnvironmentAsset — space opened prematurely?")
                let fallbackScreen = makeFallbackScreen()
                content.add(fallbackScreen)
                renderState.cinemaScreen = fallbackScreen
                setLoadingState(.failed(CustomEnvironmentFailureCopy.noEnvironmentSelected))
                return
            }
            let environmentLoadID = renderState.beginEnvironmentLoad(assetID: selected.id)
            setLoadingState(.loading)

            guard let url = await appState.environmentCatalogManager.resolvedAssetURL(for: selected) else {
                guard renderState.isCurrentEnvironmentLoad(environmentLoadID, assetID: selected.id) else { return }
                logger.warning("resolvedAssetURL returned nil for asset — file missing?")
                let fallbackScreen = makeFallbackScreen()
                content.add(fallbackScreen)
                renderState.cinemaScreen = fallbackScreen
                setLoadingState(.failed(CustomEnvironmentFailureCopy.missingEnvironmentFile))
                return
            }
            guard renderState.isCurrentEnvironmentLoad(environmentLoadID, assetID: selected.id) else { return }

            do {
                let entity = try await Entity(contentsOf: url)
                guard renderState.isCurrentEnvironmentLoad(environmentLoadID, assetID: selected.id) else { return }
                content.add(entity)
                if let screen = findScreenEntity(in: entity) {
                    renderState.cinemaScreen = screen
                    setLoadingState(.loaded)
                } else {
                    let fallbackScreen = makeFallbackScreen()
                    content.add(fallbackScreen)
                    renderState.cinemaScreen = fallbackScreen
                    logger.warning("No screen mesh found in custom environment '\(selected.name, privacy: .public)'")
                    setLoadingState(.failed(CustomEnvironmentFailureCopy.missingScreenSurface))
                }
            } catch {
                guard renderState.isCurrentEnvironmentLoad(environmentLoadID, assetID: selected.id) else { return }
                let reason = IndexerLogSanitizer.redactedErrorMessage(error)
                logger.error("Entity(contentsOf:) failed — \(reason, privacy: .public)")
                let fallbackScreen = makeFallbackScreen()
                content.add(fallbackScreen)
                renderState.cinemaScreen = fallbackScreen
                setLoadingState(.failed(CustomEnvironmentFailureCopy.resourceFailure))
            }

            // MARK: Subtitle attachment
            if let subtitlePanel = attachments.entity(for: "immersiveSubtitle") {
                // Position below the screen if found, otherwise a sensible default.
                if let screen = renderState.cinemaScreen {
                    let bounds = screen.visualBounds(relativeTo: nil)
                    subtitlePanel.position = SIMD3<Float>(
                        screen.position.x,
                        screen.position.y + bounds.min.y - 0.15,
                        screen.position.z
                    )
                    subtitlePanel.orientation = screen.orientation
                } else {
                    subtitlePanel.position = SIMD3<Float>(0, 0.6, -4)
                }
                content.add(subtitlePanel)
                renderState.subtitleEntity = subtitlePanel
            }

        } update: { content, attachments in
            // MARK: Cinema screen material (cached)
            if let screen = renderState.cinemaScreen {
                let currentSourceID: ObjectIdentifier? = {
                    if let r = appState.activeVideoRenderer { return ObjectIdentifier(r) }
                    if let p = appState.activeAVPlayer { return ObjectIdentifier(p) }
                    return nil
                }()

                if currentSourceID != renderState.lastMaterialSourceID {
                    if let renderer = appState.activeVideoRenderer {
                        screen.model?.materials = [VideoMaterial(videoRenderer: renderer)]
                    } else if let player = appState.activeAVPlayer {
                        screen.model?.materials = [VideoMaterial(avPlayer: player)]
                    } else {
                        screen.model?.materials = [SimpleMaterial(color: .black, isMetallic: false)]
                    }
                    renderState.lastMaterialSourceID = currentSourceID
                }
            }

            if let tapCatcher = renderState.tapCatcher,
               let screen = renderState.cinemaScreen {
                let bounds = screen.visualBounds(relativeTo: nil)
                updateTapCatcher(
                    tapCatcher,
                    screenPosition: screen.position,
                    screenOrientation: screen.orientation,
                    width: max(ScreenSizePreset.personal.width, bounds.extents.x),
                    height: max(ScreenSizePreset.personal.height, bounds.extents.y)
                )
            }

            // MARK: Subtitle position tracking
            if let subEnt = attachments.entity(for: "immersiveSubtitle"),
               let screen = renderState.cinemaScreen {
                let bounds = screen.visualBounds(relativeTo: nil)
                subEnt.position = SIMD3<Float>(
                    screen.position.x,
                    screen.position.y + bounds.min.y - 0.15,
                    screen.position.z
                )
                subEnt.orientation = screen.orientation
                renderState.subtitleEntity = subEnt
            }

            // MARK: Controls anchor tracking
            if let anchor = renderState.controlsAnchor {
                if headTracker.isTracking {
                    let m = headTracker.headTransform
                    let col3 = m.columns.3
                    let headPos = SIMD3<Float>(
                        col3.x,
                        col3.y + ImmersiveControlsPolicy.controlsVerticalOffset,
                        col3.z
                    )
                    let col2 = m.columns.2
                    let forward = ImmersiveControlsPolicy.safeHorizontalForward(from: col2)
                    let controlsOffset = ImmersiveControlsPolicy.controlsForwardOffset(
                        forScreenDistance: ScreenSizePreset.cinema.distance
                    )
                    let target = headPos + forward * controlsOffset
                    anchor.position = ImmersiveControlsPolicy.smoothedPosition(
                        current: anchor.position,
                        target: target
                    )
                } else {
                    anchor.position = ImmersiveControlsPolicy.fallbackControlsPosition
                }
            }

        } attachments: {
            Attachment(id: "playerControls") {
                if isShowingImmersiveControls {
                    ImmersivePlayerControlsView(showsScreenSizeControl: false)
                        .frame(width: 520)
                        .transition(.opacity.combined(with: .scale(scale: 0.92)))
                }
            }

            Attachment(id: "immersiveSubtitle") {
                if let subtitleText = engine.currentSubtitleText, !subtitleText.isEmpty {
                    ImmersiveSubtitleRenderer(
                        text: subtitleText,
                        fontSize: subtitleFontSize,
                        maxWidth: ScreenSizePreset.cinema.subtitleMaxWidth
                    )
                    .transition(.opacity)
                    .animation(accessibilityReduceMotion ? nil : .easeInOut(duration: 0.15), value: subtitleText)
                }
            }

            Attachment(id: "loadingIndicator") {
                switch loadingState {
                case .loading:
                    loadingView
                case .failed(let message):
                    errorView(message: message)
                case .loaded:
                    EmptyView()
                }
            }
        }
        .gesture(
            TapGesture()
                .targetedToAnyEntity()
                .onEnded { _ in
                    NotificationCenter.default.post(name: .immersiveTapCatcherDidFire, object: nil)
                }
        )
        .id(appState.selectedEnvironmentAsset?.id ?? "no-environment")
        .preferredSurroundingsEffect(.systemDark)
        .onReceive(NotificationCenter.default.publisher(for: .immersiveTapCatcherDidFire)) { _ in
            performOptionalAnimation(.easeInOut(duration: 0.25)) {
                isShowingImmersiveControls.toggle()
            }
            headTracker.isIdle = !isShowingImmersiveControls
            scheduleAutoDismiss()
        }
        .onReceive(NotificationCenter.default.publisher(for: .immersiveControlTogglePlayPause)) { _ in
            scheduleAutoDismiss()
        }
        .onReceive(NotificationCenter.default.publisher(for: .immersiveControlSeekToPercent)) { _ in
            scheduleAutoDismiss()
        }
        .onReceive(NotificationCenter.default.publisher(for: .immersiveControlSeekBack)) { _ in
            scheduleAutoDismiss()
        }
        .onReceive(NotificationCenter.default.publisher(for: .immersiveControlSeekForward)) { _ in
            scheduleAutoDismiss()
        }
        .onReceive(NotificationCenter.default.publisher(for: .immersiveControlCycleScreenSize)) { _ in
            // Custom USDZ environments have a fixed screen mesh — screen cycling is
            // a no-op, but we still reset the auto-dismiss timer for consistency.
            scheduleAutoDismiss()
        }
        .onAppear {
            appState.immersiveSpaceDidAppear(.customEnvironment)
            headTracker.start()
            Task { await loadSubtitleAppearance() }
        }
        .onDisappear {
            appState.immersiveSpaceDidDisappear()
            headTracker.stop()
            renderState.reset()
        }
    }

    /// Schedules auto-hide of controls after 10 seconds (OpenImmersive pattern).
    private func scheduleAutoDismiss() {
        renderState.autoDismissTask?.cancel()
        guard isShowingImmersiveControls else { return }
        renderState.autoDismissTask = Task {
            try? await Task.sleep(for: ImmersiveControlsPolicy.autoDismissInterval)
            guard !Task.isCancelled else { return }
            performOptionalAnimation(.easeInOut(duration: 0.25)) {
                isShowingImmersiveControls = false
            }
            headTracker.isIdle = true
        }
    }

    @MainActor
    private func setLoadingState(_ state: LoadingState) {
        guard loadingState != state else { return }
        loadingState = state
    }

    private func performOptionalAnimation(_ animation: Animation, updates: () -> Void) {
        if accessibilityReduceMotion {
            updates()
        } else {
            withAnimation(animation, updates)
        }
    }

    @MainActor
    private func loadSubtitleAppearance() async {
        let storedSize = (try? await appState.settingsManager.getString(key: SettingsKeys.subtitleFontSize))
            .flatMap(Double.init)
        subtitleFontSize = storedSize.map { max(16, min(48, $0)) } ?? ScreenSizePreset.cinema.subtitleFontSize
    }

    /// Recursively scan the USDZ hierarchy to find the mesh intended to be the movie screen.
    private func findScreenEntity(in root: Entity) -> ModelEntity? {
        let keywords = ["screen", "display", "tv", "monitor", "cinema", "video"]
        let lowerName = root.name.lowercased()

        if let modelEntity = root as? ModelEntity,
           keywords.contains(where: { lowerName.containsStandaloneToken($0) }) {
            logger.info("Anchored video to USDZ mesh '\(root.name, privacy: .public)'")
            return modelEntity
        }

        for child in root.children {
            if let found = findScreenEntity(in: child) {
                return found
            }
        }
        return nil
    }

    private func makeFallbackScreen() -> ModelEntity {
        let mesh = MeshResource.generatePlane(
            width: ScreenSizePreset.personal.width,
            height: ScreenSizePreset.personal.height
        )
        let material = SimpleMaterial(color: .black, isMetallic: false)
        let screen = ModelEntity(mesh: mesh, materials: [material])
        screen.name = "custom-fallback-screen"
        screen.position = SIMD3<Float>(0, ImmersiveControlsPolicy.fallbackEyeHeight, -4)
        return screen
    }

    private func updateTapCatcher(
        _ tapCatcher: Entity,
        screenPosition: SIMD3<Float>,
        screenOrientation: simd_quatf,
        width: Float,
        height: Float
    ) {
        let tapShape = ShapeResource.generateBox(
            size: ImmersiveControlsPolicy.tapCatcherSize(screenWidth: width, screenHeight: height)
        )
        tapCatcher.components.set(CollisionComponent(shapes: [tapShape], mode: .trigger, filter: .default))
        tapCatcher.position = ImmersiveControlsPolicy.tapCatcherPosition(forScreenPosition: screenPosition)
        tapCatcher.orientation = screenOrientation
    }

    private var loadingView: some View {
        VStack(spacing: 12) {
            ProgressView()
                .tint(.white)
            Text("Loading environment…")
                .font(.callout)
                .foregroundStyle(.white.opacity(0.7))
        }
        .padding(24)
        .glassBackgroundEffect()
    }

    private func errorView(message: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.title2)
                .foregroundStyle(.yellow)
            Text("Environment Issue")
                .font(.callout.weight(.semibold))
                .foregroundStyle(.white)
            Text(message)
                .font(.caption)
                .foregroundStyle(.white.opacity(0.7))
                .multilineTextAlignment(.center)
            Button {
                NotificationCenter.default.post(name: .immersiveControlDismiss, object: nil)
            } label: {
                Text("Exit Environment")
                    .font(.callout.weight(.medium))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 8)
                    .background(.ultraThinMaterial, in: Capsule())
            }
            .buttonStyle(.plain)
            .hoverEffect(.highlight)
        }
        .padding(24)
        .frame(maxWidth: 320)
        .glassBackgroundEffect()
    }
}
#endif
