import Foundation

enum HDRISkyboxGroundPolicy {
    static let groundY: Float = 0
    static let ambientRimY: Float = 0.08
}

#if os(visionOS)
import SwiftUI
import RealityKit
import ImageIO
import os

private let logger = Logger(subsystem: "com.vpstudio", category: "HDRISkybox")

enum HDRISkyboxFailureCopy {
    static let noEnvironmentSelected = "No environment selected. Playing on a plain screen."
    static let missingEnvironmentFile = "The selected environment file is missing. Playing on a plain screen."
    static let decodeFailure = "This panorama could not be decoded. Playing on a plain screen."
    static let resourceFailure = "The environment failed to load. Playing on a plain screen."
}

enum HDRISkyboxImagePolicy {
    static let maximumDimension = 16_384
    static let maximumPixelCount = 67_108_864

    static func permitsDecode(width: Int, height: Int) -> Bool {
        guard width > 0, height > 0 else { return false }
        guard width <= maximumDimension, height <= maximumDimension else { return false }
        guard width <= Int.max / height else { return false }
        return width * height <= maximumPixelCount
    }
}

enum HDRISkyboxTransitionPolicy {
    static let fadeStepCount = 8
    static let fadeDurationNanoseconds: UInt64 = 220_000_000

    static var fadeStepDelayNanoseconds: UInt64 {
        fadeDurationNanoseconds / UInt64(max(fadeStepCount, 1))
    }

    static func fadeProgress(step: Int) -> Float {
        guard fadeStepCount > 0 else { return 1 }
        let clamped = max(0, min(step, fadeStepCount))
        return Float(clamped) / Float(fadeStepCount)
    }
}

// MARK: - Screen Size Presets

/// Cinema screen size/distance presets. Cycle with `.immersiveControlCycleScreenSize`.
enum ScreenSizePreset: String, CaseIterable, Sendable {
    case personal = "Personal"
    case cinema   = "Cinema"
    case imax     = "IMAX"

    var width: Float {
        switch self {
        case .personal: 6
        case .cinema:   10
        case .imax:     16
        }
    }

    var height: Float {
        switch self {
        case .personal: 3.375
        case .cinema:   5.625
        case .imax:     9
        }
    }

    var distance: Float {
        switch self {
        case .personal: 10
        case .cinema:   20
        case .imax:     35
        }
    }

    var next: ScreenSizePreset {
        let all = Self.allCases
        guard let idx = all.firstIndex(of: self) else { return self }
        return all[(idx + 1) % all.count]
    }
}

// MARK: - View

private final class HDRISkyboxRenderState {
    var cinemaScreen: ModelEntity?
    var controlsAnchor: Entity?
    var tapCatcher: Entity?
    var subtitleEntity: Entity?
    var lastMaterialSourceID: ObjectIdentifier?
    var autoDismissTask: Task<Void, Never>?
    var hdriLoadTask: Task<CGImage?, Never>?
    var activeEnvironmentAssetID: String?
    var activeEnvironmentLoadID: UUID?
    var didAnchorScreenToHead = false

    func beginEnvironmentLoad(assetID: String) -> UUID {
        hdriLoadTask?.cancel()
        let loadID = UUID()
        activeEnvironmentAssetID = assetID
        activeEnvironmentLoadID = loadID
        hdriLoadTask = nil
        lastMaterialSourceID = nil
        return loadID
    }

    func setHDRILoadTask(_ task: Task<CGImage?, Never>, for loadID: UUID) {
        guard activeEnvironmentLoadID == loadID else {
            task.cancel()
            return
        }
        hdriLoadTask = task
    }

    func isCurrentEnvironmentLoad(_ loadID: UUID, assetID: String) -> Bool {
        activeEnvironmentLoadID == loadID && activeEnvironmentAssetID == assetID
    }

    func cancelEnvironmentLoad() {
        hdriLoadTask?.cancel()
        hdriLoadTask = nil
        activeEnvironmentAssetID = nil
        activeEnvironmentLoadID = nil
        lastMaterialSourceID = nil
    }

    func reset() {
        autoDismissTask?.cancel()
        hdriLoadTask?.cancel()
        autoDismissTask = nil
        hdriLoadTask = nil
        cinemaScreen = nil
        controlsAnchor = nil
        tapCatcher = nil
        subtitleEntity = nil
        lastMaterialSourceID = nil
        activeEnvironmentAssetID = nil
        activeEnvironmentLoadID = nil
        didAnchorScreenToHead = false
    }
}

struct HDRISkyboxEnvironment: View {
    @Environment(AppState.self) private var appState
    @Environment(VPPlayerEngine.self) private var engine
    @Environment(\.accessibilityReduceMotion) private var accessibilityReduceMotion

    @State private var headTracker = HeadTracker()
    @State private var isShowingImmersiveControls = false
    @State private var renderState = HDRISkyboxRenderState()
    @State private var screenSizePreset: ScreenSizePreset = .cinema
    @State private var loadingState: LoadingState = .loading
    @State private var subtitleFontSize: Double = 24

    private enum LoadingState: Equatable {
        case loading
        case loaded
        case failed(String)
    }

    var body: some View {
        RealityView { content, attachments in
            // MARK: Placeholder sphere (dark gradient while HDRI loads)
            let placeholderMesh = MeshResource.generateSphere(radius: 999)
            var placeholderMat = UnlitMaterial()
            placeholderMat.color = .init(tint: .init(red: 0.02, green: 0.02, blue: 0.04, alpha: 1))
            let placeholder = ModelEntity(mesh: placeholderMesh, materials: [placeholderMat])
            placeholder.scale *= SIMD3<Float>(x: -1, y: 1, z: 1)
            placeholder.components[OpacityComponent.self] = OpacityComponent(opacity: 1.0)
            placeholder.name = "hdri-placeholder"
            content.add(placeholder)

            // MARK: Cinema screen (default position, repositioned by head tracker)
            let preset = screenSizePreset
            let screenMesh = MeshResource.generatePlane(width: preset.width, height: preset.height)
            let screenMat = SimpleMaterial(color: .black, isMetallic: false)
            let screen = ModelEntity(mesh: screenMesh, materials: [screenMat])
            screen.name = "cinema-screen"
            screen.position = SIMD3<Float>(0, 1.6, -preset.distance)
            content.add(screen)
            renderState.cinemaScreen = screen

            // MARK: TapCatcher
            let tapCatcher = Entity()
            tapCatcher.name = "tap-catcher"
            tapCatcher.components.set(InputTargetComponent(allowedInputTypes: .indirect))
            updateTapCatcher(tapCatcher, for: screen, width: preset.width, height: preset.height)
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

            // MARK: Loading indicator attachment
            if let loadingPanel = attachments.entity(for: "loadingIndicator") {
                loadingPanel.position = SIMD3<Float>(0, 1.6, -4)
                content.add(loadingPanel)
            }

            // MARK: Subtitle attachment
            if let subtitlePanel = attachments.entity(for: "immersiveSubtitle") {
                subtitlePanel.position = SIMD3<Float>(
                    0,
                    screen.position.y - preset.subtitleVerticalOffset,
                    screen.position.z
                )
                content.add(subtitlePanel)
                renderState.subtitleEntity = subtitlePanel
            }

            // MARK: Async HDRI load
            guard let asset = appState.selectedEnvironmentAsset else {
                renderState.cancelEnvironmentLoad()
                setLoadingState(.failed(HDRISkyboxFailureCopy.noEnvironmentSelected))
                return
            }

            let environmentLoadID = renderState.beginEnvironmentLoad(assetID: asset.id)
            setLoadingState(.loading)

            guard let url = await appState.environmentCatalogManager.resolvedAssetURL(for: asset) else {
                guard renderState.isCurrentEnvironmentLoad(environmentLoadID, assetID: asset.id) else { return }
                setLoadingState(.failed(HDRISkyboxFailureCopy.missingEnvironmentFile))
                return
            }

            let hdriLoadTask = Task.detached(priority: .userInitiated) { () -> CGImage? in
                guard !Task.isCancelled else { return nil }
                let image = Self.loadHDRImage(from: url)
                guard !Task.isCancelled else { return nil }
                return image
            }
            renderState.setHDRILoadTask(hdriLoadTask, for: environmentLoadID)

            guard let cgImage = await hdriLoadTask.value else {
                guard renderState.isCurrentEnvironmentLoad(environmentLoadID, assetID: asset.id) else { return }
                setLoadingState(.failed(HDRISkyboxFailureCopy.decodeFailure))
                return
            }
            guard renderState.isCurrentEnvironmentLoad(environmentLoadID, assetID: asset.id) else { return }

            let yawRadians = (asset.hdriYawOffset ?? 0) * (.pi / 180.0)

            do {
                // MARK: Sky sphere
                let skyMesh = MeshResource.generateSphere(radius: 1000)
                let texture = try await TextureResource(
                    image: cgImage,
                    options: .init(semantic: .hdrColor)
                )
                guard renderState.isCurrentEnvironmentLoad(environmentLoadID, assetID: asset.id) else { return }

                var skyMaterial = UnlitMaterial()
                skyMaterial.color = .init(texture: .init(texture))

                let skyEntity = ModelEntity(mesh: skyMesh, materials: [skyMaterial])
                skyEntity.scale *= SIMD3<Float>(x: -1, y: 1, z: 1)
                skyEntity.components[OpacityComponent.self] = OpacityComponent(opacity: 0.0)
                if yawRadians != 0 {
                    skyEntity.orientation = simd_quatf(angle: yawRadians, axis: [0, 1, 0])
                }
                skyEntity.name = "hdri-sky"
                content.add(skyEntity)

                // MARK: IBL
                let environmentResource = try await EnvironmentResource(equirectangular: cgImage)
                guard renderState.isCurrentEnvironmentLoad(environmentLoadID, assetID: asset.id) else { return }
                let iblEntity = Entity()
                iblEntity.name = "hdri-ibl"
                if yawRadians != 0 {
                    iblEntity.orientation = simd_quatf(angle: yawRadians, axis: [0, 1, 0])
                }
                iblEntity.components.set(ImageBasedLightComponent(
                    source: .single(environmentResource),
                    intensityExponent: 1.0
                ))
                content.add(iblEntity)

                // MARK: Ground plane
                let groundMaterial = SimpleMaterial(
                    color: .init(red: 0.02, green: 0.02, blue: 0.02, alpha: 0.3),
                    roughness: 0.9,
                    isMetallic: false
                )
                let ground = ModelEntity(
                    mesh: .generatePlane(width: 20, depth: 20),
                    materials: [groundMaterial]
                )
                ground.name = "hdri-ground"
                ground.components.set(ImageBasedLightReceiverComponent(imageBasedLight: iblEntity))
                content.add(ground)

                // MARK: Ambient floor rim
                let rimMesh = MeshResource.generatePlane(width: 22, depth: 22)
                var rimMat = UnlitMaterial()
                rimMat.color = .init(tint: .init(red: 0.15, green: 0.12, blue: 0.08, alpha: 0.06))
                let rimEntity = ModelEntity(mesh: rimMesh, materials: [rimMat])
                rimEntity.name = "hdri-floor-rim"
                rimEntity.position.y = HDRISkyboxGroundPolicy.ambientRimY
                content.add(rimEntity)

                await crossfadeSkybox(
                    skyEntity: skyEntity,
                    placeholder: placeholder,
                    loadID: environmentLoadID,
                    assetID: asset.id
                )
                guard renderState.isCurrentEnvironmentLoad(environmentLoadID, assetID: asset.id) else { return }
                setLoadingState(.loaded)

            } catch {
                guard renderState.isCurrentEnvironmentLoad(environmentLoadID, assetID: asset.id) else { return }
                let reason = IndexerLogSanitizer.redactedErrorMessage(error)
                logger.error("HDRI environment resource creation failed: \(reason, privacy: .public)")
                setLoadingState(.failed(HDRISkyboxFailureCopy.resourceFailure))
            }

        } update: { content, attachments in
            // MARK: Cinema screen material (cached — only rebuild when source changes)
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

            // MARK: Head-pose screen anchoring (one-shot)
            // Uses entity.look(at:from:relativeTo:forward:) from HUD gist research
            // to properly orient the screen toward the viewer. Head Y position is
            // used instead of hardcoded 1.6m (P2-055).
            if !renderState.didAnchorScreenToHead,
               let screen = renderState.cinemaScreen,
               let initial = headTracker.initialHeadTransform {
                let col3 = initial.columns.3
                let headPos = SIMD3<Float>(col3.x, col3.y, col3.z)
                let col2 = initial.columns.2
                let forward = ImmersiveControlsPolicy.safeHorizontalForward(from: col2)
                let dist = screenSizePreset.distance
                let screenPos = headPos + forward * dist
                let finalScreenPos = SIMD3<Float>(screenPos.x, headPos.y, screenPos.z)
                screen.look(at: headPos, from: finalScreenPos, relativeTo: nil, forward: .positiveZ)
                renderState.didAnchorScreenToHead = true
            }

            if let tapCatcher = renderState.tapCatcher,
               let screen = renderState.cinemaScreen {
                let preset = screenSizePreset
                updateTapCatcher(tapCatcher, for: screen, width: preset.width, height: preset.height)
            }

            // MARK: Subtitle position tracking
            if let subEnt = attachments.entity(for: "immersiveSubtitle"),
               let screen = renderState.cinemaScreen {
                let preset = screenSizePreset
                subEnt.position = SIMD3<Float>(
                    screen.position.x,
                    screen.position.y - preset.subtitleVerticalOffset,
                    screen.position.z
                )
                // Match the screen's orientation so subtitles face the viewer.
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
                        forScreenDistance: screenSizePreset.distance
                    )
                    let target = headPos + forward * controlsOffset
                    let smoothing = ImmersiveControlsPolicy.controlsAnchorSmoothing
                    anchor.position = simd_mix(
                        anchor.position, target,
                        SIMD3<Float>(repeating: smoothing)
                    )
                } else {
                    // Simulator / no ARKit — park controls at a sensible default.
                    anchor.position = ImmersiveControlsPolicy.fallbackControlsPosition
                }
            }

        } attachments: {
            Attachment(id: "playerControls") {
                if isShowingImmersiveControls {
                    ImmersivePlayerControlsView()
                        .frame(width: 520)
                        .transition(.opacity.combined(with: .scale(0.92)))
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

            Attachment(id: "immersiveSubtitle") {
                if let subtitleText = engine.currentSubtitleText, !subtitleText.isEmpty {
                    ImmersiveSubtitleRenderer(
                        text: subtitleText,
                        fontSize: subtitleFontSize,
                        maxWidth: screenSizePreset.subtitleMaxWidth
                    )
                    .transition(.opacity)
                    .animation(accessibilityReduceMotion ? nil : .easeInOut(duration: 0.15), value: subtitleText)
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
        .onReceive(NotificationCenter.default.publisher(for: .immersiveControlCycleScreenSize)) { _ in
            cycleScreenSize()
            scheduleAutoDismiss()
        }
        .onReceive(NotificationCenter.default.publisher(for: .immersiveControlTogglePlayPause)) { _ in
            scheduleAutoDismiss()
        }
        .onReceive(NotificationCenter.default.publisher(for: .immersiveControlSeekBack)) { _ in
            scheduleAutoDismiss()
        }
        .onReceive(NotificationCenter.default.publisher(for: .immersiveControlSeekForward)) { _ in
            scheduleAutoDismiss()
        }
        .onReceive(NotificationCenter.default.publisher(for: .immersiveControlSeekToPercent)) { _ in
            scheduleAutoDismiss()
        }
        .onAppear {
            appState.immersiveSpaceDidAppear(.hdriSkybox)
            headTracker.start()
            Task { await loadSubtitleAppearance() }
        }
        .onDisappear {
            appState.immersiveSpaceDidDisappear()
            headTracker.stop()
            renderState.reset()
        }
    }

    // MARK: - Screen Size Cycling

    private func cycleScreenSize() {
        let newPreset = screenSizePreset.next
        screenSizePreset = newPreset

        guard let screen = renderState.cinemaScreen else { return }

        // Regenerate mesh for new dimensions.
        screen.model?.mesh = MeshResource.generatePlane(width: newPreset.width, height: newPreset.height)

        // Calculate target position using head Y instead of hardcoded 1.6m (P2-055).
        let headPos: SIMD3<Float>
        let targetPos: SIMD3<Float>
        if renderState.didAnchorScreenToHead, let initial = headTracker.initialHeadTransform {
            let col3 = initial.columns.3
            headPos = SIMD3<Float>(col3.x, col3.y, col3.z)
            let col2 = initial.columns.2
            let forward = ImmersiveControlsPolicy.safeHorizontalForward(from: col2)
            let newPos = headPos + forward * newPreset.distance
            targetPos = SIMD3<Float>(newPos.x, headPos.y, newPos.z)
        } else {
            let eyeY = ImmersiveControlsPolicy.fallbackEyeHeight
            headPos = SIMD3<Float>(0, eyeY, 0)
            targetPos = SIMD3<Float>(0, eyeY, -newPreset.distance)
        }

        // Compute target transform with proper facing via look(at:).
        let temp = Entity()
        temp.look(at: headPos, from: targetPos, relativeTo: nil, forward: .positiveZ)
        screen.move(to: temp.transform, relativeTo: nil, duration: accessibilityReduceMotion ? 0 : 0.4)
    }

    private func updateTapCatcher(_ tapCatcher: Entity, for screen: Entity, width: Float, height: Float) {
        let tapShape = ShapeResource.generateBox(
            size: ImmersiveControlsPolicy.tapCatcherSize(screenWidth: width, screenHeight: height)
        )
        tapCatcher.components.set(CollisionComponent(shapes: [tapShape], mode: .trigger, filter: .default))
        tapCatcher.position = ImmersiveControlsPolicy.tapCatcherPosition(forScreenPosition: screen.position)
        tapCatcher.orientation = screen.orientation
    }

    // MARK: - Auto-Dismiss

    /// Schedules auto-hide of controls after the policy-defined interval.
    /// Any user interaction resets the timer.
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
        subtitleFontSize = storedSize.map { max(16, min(48, $0)) } ?? screenSizePreset.subtitleFontSize
    }

    // MARK: - Loading / Error Views

    @MainActor
    private func crossfadeSkybox(
        skyEntity: Entity,
        placeholder: Entity,
        loadID: UUID,
        assetID: String
    ) async {
        let applyOpacity: (Entity, Float) -> Void = { entity, opacity in
            entity.components[OpacityComponent.self] = OpacityComponent(opacity: opacity)
        }

        guard !accessibilityReduceMotion else {
            applyOpacity(skyEntity, 1.0)
            placeholder.removeFromParent()
            return
        }

        applyOpacity(skyEntity, 0.0)
        applyOpacity(placeholder, 1.0)

        for step in 1...HDRISkyboxTransitionPolicy.fadeStepCount {
            guard renderState.isCurrentEnvironmentLoad(loadID, assetID: assetID) else { return }
            try? await Task.sleep(nanoseconds: HDRISkyboxTransitionPolicy.fadeStepDelayNanoseconds)
            guard !Task.isCancelled,
                  renderState.isCurrentEnvironmentLoad(loadID, assetID: assetID) else { return }

            let progress = HDRISkyboxTransitionPolicy.fadeProgress(step: step)
            applyOpacity(skyEntity, progress)
            applyOpacity(placeholder, max(0, 1 - progress))
        }

        placeholder.removeFromParent()
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
            .padding(.top, 4)
        }
        .padding(24)
        .frame(maxWidth: 320)
        .glassBackgroundEffect()
    }

    // MARK: - HDRI Image Loading

    nonisolated private static func loadHDRImage(from url: URL) -> CGImage? {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else {
            logger.error("Could not create image source for \(url.lastPathComponent, privacy: .public)")
            return nil
        }

        let options: [CFString: Any] = [
            kCGImageSourceShouldCache: false,
            kCGImageSourceShouldAllowFloat: true,
        ]

        guard let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let width = Self.intImageProperty(properties[kCGImagePropertyPixelWidth]),
              let height = Self.intImageProperty(properties[kCGImagePropertyPixelHeight]),
              HDRISkyboxImagePolicy.permitsDecode(width: width, height: height) else {
            logger.error("Refusing to decode oversized environment image \(url.lastPathComponent, privacy: .public)")
            return nil
        }

        guard let image = CGImageSourceCreateImageAtIndex(source, 0, options as CFDictionary) else {
            logger.error("Could not decode image at \(url.lastPathComponent, privacy: .public)")
            return nil
        }

        return image
    }

    nonisolated private static func intImageProperty(_ value: Any?) -> Int? {
        if let intValue = value as? Int {
            return intValue
        }
        if let number = value as? NSNumber {
            return number.intValue
        }
        return nil
    }
}
#endif
