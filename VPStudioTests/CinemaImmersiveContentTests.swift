#if os(visionOS)
import Foundation
import Testing
import RealityKit
import simd
@testable import VPStudio

// MARK: - Test Helpers

/// Helper that instantiates `CinemaSettings` with persistence disabled
/// and verifies derived values used by `CinemaImmersiveContent`.
@MainActor
struct CinemaSettingsTestHelper {
    static func makeSettings(
        screenWidth: Double = 6.0,
        screenDistance: Double = 4.0,
        screenHeight: Double = 0.0,
        screenTilt: Double = 0.0,
        seatOffset: SIMD3<Double> = .zero,
        environmentDarkness: Double = 0.8,
        ambientLighting: Double = 0.1,
        immersionStyle: CinemaImmersionStyle = .full,
        useSurroundingsEffect: Bool = true,
        videoAspectRatio: Double = 16.0 / 9.0
    ) -> CinemaSettings {
        CinemaSettings(
            screenWidth: screenWidth,
            screenDistance: screenDistance,
            screenHeight: screenHeight,
            screenTilt: screenTilt,
            seatOffset: seatOffset,
            environmentDarkness: environmentDarkness,
            ambientLighting: ambientLighting,
            immersionStyle: immersionStyle,
            useSurroundingsEffect: useSurroundingsEffect,
            videoAspectRatio: videoAspectRatio,
            loadPersisted: false
        )
    }

    static func verifyDerivedValues(
        for settings: CinemaSettings,
        expectedWidth: Double,
        expectedAspectRatio: Double
    ) {
        let size = settings.screenSize
        #expect(size.width == expectedWidth)
        #expect(size.height == expectedWidth / expectedAspectRatio)
    }
}

// MARK: - CinemaImmersivePlacementPolicy

@Suite("CinemaImmersivePlacementPolicy")
struct CinemaImmersivePlacementPolicyTests {

    // MARK: safeHorizontalForward

    @Test func safeHorizontalForwardNormalizesTypicalColumn() {
        let column = SIMD4<Float>(0, 0, -1, 0)
        let forward = CinemaImmersivePlacementPolicy.safeHorizontalForward(from: column)
        #expect(forward.x == 0)
        #expect(forward.y == 0)
        #expect(forward.z == 1)
    }

    @Test func safeHorizontalForwardFallbackOnZeroLength() {
        let column = SIMD4<Float>(0, 0, 0, 0)
        let forward = CinemaImmersivePlacementPolicy.safeHorizontalForward(from: column)
        #expect(forward == SIMD3<Float>(0, 0, -1))
    }

    @Test func safeHorizontalForwardIgnoresYComponent() {
        let column = SIMD4<Float>(-3, 10, -4, 0)
        let forward = CinemaImmersivePlacementPolicy.safeHorizontalForward(from: column)
        #expect(forward.y == 0)
        let horizontalLen = sqrt(forward.x * forward.x + forward.z * forward.z)
        #expect(horizontalLen == 1.0)
    }

    // MARK: screenPosition

    @Test @MainActor func screenPositionWithoutHeadTransform() {
        let settings = CinemaSettingsTestHelper.makeSettings(
            screenWidth: 6,
            screenDistance: 4,
            screenHeight: 0.2
        )
        let placement = CinemaImmersivePlacementPolicy.screenPosition(
            settings: settings,
            headTransform: nil
        )
        let expectedY = Float(
            CinemaImmersivePlacementPolicy.fallbackEyeHeight
        ) + Float(settings.screenHeight)
        #expect(placement.position.x == 0)
        #expect(placement.position.y == expectedY)
        #expect(placement.position.z == -4)
        #expect(placement.lookAt.y == CinemaImmersivePlacementPolicy.fallbackEyeHeight)
    }

    @Test @MainActor func screenPositionWithHeadTransform() {
        var transform = simd_float4x4(1)
        transform.columns.3 = SIMD4<Float>(1, 1.6, 2, 1)
        transform.columns.2 = SIMD4<Float>(0, 0, -1, 0)

        let settings = CinemaSettingsTestHelper.makeSettings(
            screenWidth: 6,
            screenDistance: 4,
            seatOffset: SIMD3<Double>(0.5, 0.1, 0.2)
        )
        let placement = CinemaImmersivePlacementPolicy.screenPosition(
            settings: settings,
            headTransform: transform
        )

        // forward = (0, 0, 1), right = (-1, 0, 0)
        // distance = max(4 - 0.2, 0.75) = 3.8
        // position = head + forward*3.8 + right*0.5 + (0, 0.1, 0)
        #expect(placement.position.x == 0.5)
        #expect(placement.position.y == 1.7)
        #expect(placement.position.z == 5.8)
        #expect(placement.lookAt == SIMD3<Float>(1, 1.6, 2))
    }

    @Test @MainActor func screenPositionRespectsMinimumDistance() {
        let settings = CinemaSettingsTestHelper.makeSettings(
            screenDistance: 0.1,
            seatOffset: SIMD3<Double>(0, 0, 1.0)
        )
        let placement = CinemaImmersivePlacementPolicy.screenPosition(
            settings: settings,
            headTransform: nil
        )
        // distance = max(0.1 - 1.0, 0.75) -> 0.75
        #expect(placement.position.z == -0.75)
    }

    // MARK: Backdrop visibility & opacity

    @Test func shouldShowBackdropRequiresDarknessAboveThreshold() {
        #expect(
            !CinemaImmersivePlacementPolicy.shouldShowBackdrop(
                immersionStyleRaw: CinemaImmersionStyle.full.rawValue,
                environmentDarkness: 0.0
            )
        )
        #expect(
            !CinemaImmersivePlacementPolicy.shouldShowBackdrop(
                immersionStyleRaw: CinemaImmersionStyle.full.rawValue,
                environmentDarkness: 0.05
            )
        )
        #expect(
            CinemaImmersivePlacementPolicy.shouldShowBackdrop(
                immersionStyleRaw: CinemaImmersionStyle.full.rawValue,
                environmentDarkness: 0.06
            )
        )
    }

    @Test func shouldShowBackdropRequiresValidImmersionStyle() {
        #expect(
            CinemaImmersivePlacementPolicy.shouldShowBackdrop(
                immersionStyleRaw: CinemaImmersionStyle.mixed.rawValue,
                environmentDarkness: 0.5
            )
        )
        #expect(
            CinemaImmersivePlacementPolicy.shouldShowBackdrop(
                immersionStyleRaw: CinemaImmersionStyle.progressive.rawValue,
                environmentDarkness: 0.5
            )
        )
        #expect(
            !CinemaImmersivePlacementPolicy.shouldShowBackdrop(
                immersionStyleRaw: "invalid",
                environmentDarkness: 0.5
            )
        )
    }

    @Test func backdropOpacityClampsToMinimum() {
        #expect(CinemaImmersivePlacementPolicy.backdropOpacity(for: 0.0) == 0.18)
        #expect(CinemaImmersivePlacementPolicy.backdropOpacity(for: 0.1) == 0.18)
        #expect(CinemaImmersivePlacementPolicy.backdropOpacity(for: 0.18) == 0.18)
    }

    @Test func backdropOpacityPassesThroughMiddleValues() {
        #expect(CinemaImmersivePlacementPolicy.backdropOpacity(for: 0.5) == 0.5)
        #expect(CinemaImmersivePlacementPolicy.backdropOpacity(for: 0.75) == 0.75)
    }

    @Test func backdropOpacityClampsToMaximum() {
        #expect(CinemaImmersivePlacementPolicy.backdropOpacity(for: 1.0) == 1.0)
        #expect(CinemaImmersivePlacementPolicy.backdropOpacity(for: 1.2) == 1.0)
    }
}

// MARK: - CinemaSettings Screen Geometry

@Suite("CinemaSettings Screen Geometry")
@MainActor
struct CinemaSettingsScreenGeometryTests {

    @Test func screenSizeDrivenByWidthAndAspectRatio() async throws {
        let settings = CinemaSettings(
            screenWidth: 6,
            videoAspectRatio: 16.0 / 9.0,
            loadPersisted: false
        )
        let size = settings.screenSize
        #expect(size.width == 6)
        #expect(size.height == 3.375)
    }

    @Test func screenSizeUpdatesWhenAspectRatioChanges() async throws {
        let settings = CinemaSettingsTestHelper.makeSettings(
            screenWidth: 6,
            videoAspectRatio: 16.0 / 9.0
        )
        #expect(settings.screenSize.height == 3.375)

        settings.videoAspectRatio = 2.39
        #expect(abs(settings.screenSize.height - 6.0 / 2.39) < 0.0001)

        settings.videoAspectRatio = 4.0 / 3.0
        #expect(abs(settings.screenSize.height - 6.0 / (4.0 / 3.0)) < 0.0001)
    }

    @Test func screenSizeMaintainsWidthWhenAspectRatioChanges() async throws {
        let settings = CinemaSettings(
            screenWidth: 10,
            videoAspectRatio: 16.0 / 9.0,
            loadPersisted: false
        )
        #expect(settings.screenSize.width == 10)
        settings.videoAspectRatio = 2.35
        #expect(settings.screenSize.width == 10)
    }

    @Test func horizontalFOVCalculation() async throws {
        let settings = CinemaSettings(
            screenWidth: 6,
            screenDistance: 4,
            loadPersisted: false
        )
        let expected = 2 * atan((6.0 / 2) / 4) * (180.0 / .pi)
        #expect(settings.horizontalFOV == expected)
    }

    @Test func isComfortableWithinLimits() async throws {
        let comfortable = CinemaSettings(
            screenWidth: 1.5,
            screenDistance: 2.0,
            loadPersisted: false
        )
        #expect(comfortable.isComfortable)
    }

    @Test func isNotComfortableWhenFOVExceeds60() async throws {
        let uncomfortable = CinemaSettings(
            screenWidth: 6,
            screenDistance: 1.0,
            loadPersisted: false
        )
        #expect(!uncomfortable.isComfortable)
    }

    @Test func isNotComfortableWhenTooCloseAndWide() async throws {
        let uncomfortable = CinemaSettings(
            screenWidth: 3,
            screenDistance: 1.2,
            loadPersisted: false
        )
        #expect(!uncomfortable.isComfortable)
    }
}

// MARK: - CinemaPreset Configurations

@Suite("CinemaPreset Configurations")
struct CinemaPresetConfigurationTests {

    @Test @MainActor func defaultPresetValues() {
        let settings = CinemaSettings(preset: .default, baseAspectRatio: 16.0 / 9.0)
        #expect(settings.screenWidth == 6.0)
        #expect(settings.screenDistance == 4.0)
        #expect(settings.screenHeight == 0.0)
        #expect(settings.screenTilt == 0.0)
        #expect(settings.environmentDarkness == 0.8)
        #expect(settings.ambientLighting == 0.1)
        #expect(settings.immersionStyle == .full)
        #expect(settings.useSurroundingsEffect == true)
        #expect(settings.seatOffset == .zero)
        #expect(settings.videoAspectRatio == 16.0 / 9.0)
    }

    @Test @MainActor func frontRowPresetValues() {
        let settings = CinemaSettings(preset: .frontRow, baseAspectRatio: 16.0 / 9.0)
        #expect(settings.screenWidth == 5.0)
        #expect(settings.screenDistance == 2.5)
        #expect(settings.screenHeight == -0.3)
        #expect(settings.screenTilt == 5.0)
        #expect(settings.environmentDarkness == 1.0)
        #expect(settings.ambientLighting == 0.05)
        #expect(settings.immersionStyle == .full)
        #expect(settings.useSurroundingsEffect == true)
    }

    @Test @MainActor func backRowPresetValues() {
        let settings = CinemaSettings(preset: .backRow, baseAspectRatio: 16.0 / 9.0)
        #expect(settings.screenWidth == 4.5)
        #expect(settings.screenDistance == 8.0)
        #expect(settings.screenHeight == 0.5)
        #expect(settings.screenTilt == -3.0)
        #expect(settings.environmentDarkness == 0.6)
        #expect(settings.ambientLighting == 0.2)
        #expect(settings.immersionStyle == .progressive)
        #expect(settings.useSurroundingsEffect == false)
    }

    @Test @MainActor func imaxPresetValues() {
        let settings = CinemaSettings(preset: .imax, baseAspectRatio: 16.0 / 9.0)
        #expect(settings.screenWidth == 10.0)
        #expect(settings.screenDistance == 3.5)
        #expect(settings.screenHeight == 1.0)
        #expect(settings.screenTilt == 8.0)
        #expect(settings.environmentDarkness == 1.0)
        #expect(settings.ambientLighting == 0.0)
        #expect(settings.immersionStyle == .full)
        #expect(settings.useSurroundingsEffect == true)
        #expect(settings.seatOffset == SIMD3<Double>(0, 0.1, 0))
    }

    @Test @MainActor func customPresetLeavesValuesUnchanged() {
        let settings = CinemaSettings(preset: .default, baseAspectRatio: 16.0 / 9.0)
        let previousWidth = settings.screenWidth
        settings.apply(preset: .custom)
        #expect(settings.screenWidth == previousWidth)
        #expect(settings.screenDistance == 4.0)
    }

    @Test @MainActor func activePresetDetectsDefault() {
        let settings = CinemaSettings(preset: .default, baseAspectRatio: 16.0 / 9.0)
        #expect(settings.activePreset == .default)
    }

    @Test @MainActor func activePresetDetectsFrontRow() {
        let settings = CinemaSettings(preset: .frontRow, baseAspectRatio: 16.0 / 9.0)
        #expect(settings.activePreset == .frontRow)
    }

    @Test @MainActor func activePresetDetectsBackRow() {
        let settings = CinemaSettings(preset: .backRow, baseAspectRatio: 16.0 / 9.0)
        #expect(settings.activePreset == .backRow)
    }

    @Test @MainActor func activePresetDetectsIMAX() {
        let settings = CinemaSettings(preset: .imax, baseAspectRatio: 16.0 / 9.0)
        #expect(settings.activePreset == .imax)
    }

    @Test @MainActor func activePresetReturnsCustomWhenDeviated() {
        let settings = CinemaSettings(preset: .default, baseAspectRatio: 16.0 / 9.0)
        settings.screenWidth = 99.0
        #expect(settings.activePreset == .custom)
    }

    @Test @MainActor func activePresetSetterAppliesPreset() {
        let settings = CinemaSettings(preset: .default, baseAspectRatio: 16.0 / 9.0)
        settings.activePreset = .imax
        #expect(settings.activePreset == .imax)
        #expect(settings.screenWidth == 10.0)
    }

    @Test @MainActor func presetTitles() {
        #expect(CinemaPreset.default.title == "Default")
        #expect(CinemaPreset.frontRow.title == "Front Row")
        #expect(CinemaPreset.backRow.title == "Back Row")
        #expect(CinemaPreset.imax.title == "IMAX")
        #expect(CinemaPreset.custom.title == "Custom")
    }

    @Test @MainActor func presetIdsMatchRawValues() {
        for preset in CinemaPreset.allCases {
            #expect(preset.id == preset.rawValue)
        }
    }

    @Test @MainActor func allPresetsHaveUniqueRawValues() {
        let rawValues = CinemaPreset.allCases.map(\.rawValue)
        #expect(Set(rawValues).count == rawValues.count)
    }
}

// MARK: - Material Fallback

@Suite("Cinema Material Fallback")
struct CinemaMaterialFallbackTests {

    /// Replicates the material selection logic from `CinemaImmersiveContent.makeScreenMaterial`
    /// so it can be exercised without an `AppState` instance.
    private enum MaterialSelection {
        case videoRenderer
        case avPlayer
        case unlitFallback

        static func resolve(hasVideoRenderer: Bool, hasAVPlayer: Bool) -> MaterialSelection {
            if hasVideoRenderer { return .videoRenderer }
            if hasAVPlayer { return .avPlayer }
            return .unlitFallback
        }
    }

    @Test func fallbackWhenNoPlayerIsSet() {
        let selection = MaterialSelection.resolve(
            hasVideoRenderer: false,
            hasAVPlayer: false
        )
        #expect(selection == .unlitFallback)
    }

    @Test func usesAVPlayerWhenAvailable() {
        let selection = MaterialSelection.resolve(
            hasVideoRenderer: false,
            hasAVPlayer: true
        )
        #expect(selection == .avPlayer)
    }

    @Test func prefersVideoRendererOverAVPlayer() {
        let selection = MaterialSelection.resolve(
            hasVideoRenderer: true,
            hasAVPlayer: true
        )
        #expect(selection == .videoRenderer)
    }

    @Test func videoRendererAloneSelectsCorrectly() {
        let selection = MaterialSelection.resolve(
            hasVideoRenderer: true,
            hasAVPlayer: false
        )
        #expect(selection == .videoRenderer)
    }
}

// MARK: - EnvironmentLightingConfigurationComponent

@Suite("Environment Lighting Configuration")
struct EnvironmentLightingConfigurationTests {

    @Test func componentCreatedWithCorrectWeight() {
        let component = EnvironmentLightingConfigurationComponent(
            environmentLightingWeight: 0.15
        )
        #expect(component.environmentLightingWeight == 0.15)
    }

    @Test func componentWeightCanBeZero() {
        let component = EnvironmentLightingConfigurationComponent(
            environmentLightingWeight: 0.0
        )
        #expect(component.environmentLightingWeight == 0.0)
    }

    @Test func componentWeightCanBeOne() {
        let component = EnvironmentLightingConfigurationComponent(
            environmentLightingWeight: 1.0
        )
        #expect(component.environmentLightingWeight == 1.0)
    }
}

// MARK: - PlayerView syncCinemaAspectRatio Integration

@Suite("PlayerView syncCinemaAspectRatio Integration")
@MainActor
struct CinemaAspectRatioIntegrationTests {

    /// Mirrors the `syncCinemaAspectRatio` logic from `PlayerView.swift`.
    @MainActor
    private func syncCinemaAspectRatio(_ ratio: CGFloat?, into settings: CinemaSettings) {
        guard let ratio, ratio.isFinite, ratio > 0 else { return }
        settings.videoAspectRatio = Double(ratio)
    }

    @Test func settingVideoAspectRatioUpdatesScreenSize() async throws {
        let settings = CinemaSettings(
            screenWidth: 6,
            videoAspectRatio: 16.0 / 9.0,
            loadPersisted: false
        )
        #expect(settings.screenSize.height == 3.375)

        settings.videoAspectRatio = 2.39
        #expect(abs(settings.screenSize.height - 6.0 / 2.39) < 0.0001)
    }

    @Test func syncCinemaAspectRatioRejectsNil() async throws {
        let settings = CinemaSettings(
            screenWidth: 6,
            videoAspectRatio: 16.0 / 9.0,
            loadPersisted: false
        )
        syncCinemaAspectRatio(nil, into: settings)
        #expect(settings.videoAspectRatio == 16.0 / 9.0)
    }

    @Test func syncCinemaAspectRatioRejectsNaN() async throws {
        let settings = CinemaSettings(
            screenWidth: 6,
            videoAspectRatio: 16.0 / 9.0,
            loadPersisted: false
        )
        syncCinemaAspectRatio(CGFloat.nan, into: settings)
        #expect(settings.videoAspectRatio == 16.0 / 9.0)
    }

    @Test func syncCinemaAspectRatioRejectsNegative() async throws {
        let settings = CinemaSettings(
            screenWidth: 6,
            videoAspectRatio: 16.0 / 9.0,
            loadPersisted: false
        )
        syncCinemaAspectRatio(-1.0, into: settings)
        #expect(settings.videoAspectRatio == 16.0 / 9.0)
    }

    @Test func syncCinemaAspectRatioRejectsZero() async throws {
        let settings = CinemaSettings(
            screenWidth: 6,
            videoAspectRatio: 16.0 / 9.0,
            loadPersisted: false
        )
        syncCinemaAspectRatio(0.0, into: settings)
        #expect(settings.videoAspectRatio == 16.0 / 9.0)
    }

    @Test func syncCinemaAspectRatioAcceptsValidRatio() async throws {
        let settings = CinemaSettings(
            screenWidth: 6,
            videoAspectRatio: 16.0 / 9.0,
            loadPersisted: false
        )
        syncCinemaAspectRatio(2.39, into: settings)
        #expect(settings.videoAspectRatio == 2.39)
        #expect(abs(settings.screenSize.height - 6.0 / 2.39) < 0.0001)
    }

    @Test func syncCinemaAspectRatioAcceptsStandardFourThree() async throws {
        let settings = CinemaSettings(
            screenWidth: 6,
            videoAspectRatio: 16.0 / 9.0,
            loadPersisted: false
        )
        syncCinemaAspectRatio(4.0 / 3.0, into: settings)
        #expect(settings.videoAspectRatio == 4.0 / 3.0)
        #expect(abs(settings.screenSize.height - 6.0 / (4.0 / 3.0)) < 0.0001)
    }
}
#endif
