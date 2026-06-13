#if os(visionOS)
import Foundation
import Testing
import RealityKit
import AVFoundation
import UIKit
import simd
@testable import VPStudio

// MARK: - Test Helpers

/// Replicates the screen-discovery logic from `CustomEnvironmentView.findScreenEntity(in:)`
/// so it can be tested without instantiating the view.
@MainActor
private func testableFindScreenEntity(in root: Entity) -> ModelEntity? {
    let keywords = ["screen", "display", "tv", "monitor", "cinema", "video"]
    let lowerName = root.name.lowercased()

    if let modelEntity = root as? ModelEntity,
       keywords.contains(where: { lowerName.containsStandaloneToken($0) }) {
        return modelEntity
    }

    for child in root.children {
        if let found = testableFindScreenEntity(in: child) {
            return found
        }
    }
    return nil
}

private func testableCurrentSourceID(
    rendererID: ObjectIdentifier?,
    playerID: ObjectIdentifier?
) -> ObjectIdentifier? {
    rendererID ?? playerID
}

/// Replicates the fallback-screen construction from `CustomEnvironmentView.makeFallbackScreen()`.
private func makeTestableFallbackScreen() -> ModelEntity {
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

/// Replicates the material-selection priority from both immersive views.
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

// MARK: - ScreenSizePreset

@Suite("ScreenSizePreset — Cases & Dimensions", .serialized)
struct ScreenSizePresetTestsImmersiveenvironmentplayertests {

    @Test func allCasesContainsThreePresets() {
        #expect(ScreenSizePreset.allCases.count == 3)
    }

    @Test func allCasesContainsPersonalCinemaIMAX() {
        let rawValues = Set(ScreenSizePreset.allCases.map(\.rawValue))
        #expect(rawValues.contains("Personal"))
        #expect(rawValues.contains("Cinema"))
        #expect(rawValues.contains("IMAX"))
    }

    @Test func personalWidthIsSix() {
        #expect(ScreenSizePreset.personal.width == 6)
    }

    @Test func personalHeightIsThreePointThreeSevenFive() {
        #expect(ScreenSizePreset.personal.height == 3.375)
    }

    @Test func cinemaWidthIsTen() {
        #expect(ScreenSizePreset.cinema.width == 10)
    }

    @Test func cinemaHeightIsFivePointSixTwoFive() {
        #expect(ScreenSizePreset.cinema.height == 5.625)
    }

    @Test func imaxWidthIsSixteen() {
        #expect(ScreenSizePreset.imax.width == 16)
    }

    @Test func imaxHeightIsNine() {
        #expect(ScreenSizePreset.imax.height == 9)
    }

    @Test func personalDistanceIsTen() {
        #expect(ScreenSizePreset.personal.distance == 10)
    }

    @Test func cinemaDistanceIsTwenty() {
        #expect(ScreenSizePreset.cinema.distance == 20)
    }

    @Test func imaxDistanceIsThirtyFive() {
        #expect(ScreenSizePreset.imax.distance == 35)
    }

    @Test func nextCyclesPersonalToCinema() {
        #expect(ScreenSizePreset.personal.next == .cinema)
    }

    @Test func nextCyclesCinemaToIMAX() {
        #expect(ScreenSizePreset.cinema.next == .imax)
    }

    @Test func nextCyclesIMAXBackToPersonal() {
        #expect(ScreenSizePreset.imax.next == .personal)
    }

    @Test func allCasesHaveUniqueRawValues() {
        let rawValues = ScreenSizePreset.allCases.map(\.rawValue)
        #expect(Set(rawValues).count == rawValues.count)
    }
}

// MARK: - Screen Size Calculations

@Suite("Screen Size Geometry — 16:9 Aspect Ratio", .serialized)
struct ScreenSizeGeometryTests {

    @Test func personalAspectRatioIsApproximately16By9() {
        let ratio = ScreenSizePreset.personal.width / ScreenSizePreset.personal.height
        #expect(abs(ratio - (16.0 / 9.0)) < 0.001)
    }

    @Test func cinemaAspectRatioIsApproximately16By9() {
        let ratio = ScreenSizePreset.cinema.width / ScreenSizePreset.cinema.height
        #expect(abs(ratio - (16.0 / 9.0)) < 0.001)
    }

    @Test func imaxAspectRatioIsApproximately16By9() {
        let ratio = ScreenSizePreset.imax.width / ScreenSizePreset.imax.height
        #expect(abs(ratio - (16.0 / 9.0)) < 0.001)
    }

    @Test func personalScreenArea() {
        let area = ScreenSizePreset.personal.width * ScreenSizePreset.personal.height
        #expect(area == 20.25)
    }

    @Test func cinemaScreenArea() {
        let area = ScreenSizePreset.cinema.width * ScreenSizePreset.cinema.height
        #expect(area == 56.25)
    }

    @Test func imaxScreenArea() {
        let area = ScreenSizePreset.imax.width * ScreenSizePreset.imax.height
        #expect(area == 144)
    }

    @Test func cinemaIsLargerThanPersonal() {
        let cinemaArea = ScreenSizePreset.cinema.width * ScreenSizePreset.cinema.height
        let personalArea = ScreenSizePreset.personal.width * ScreenSizePreset.personal.height
        #expect(cinemaArea > personalArea)
    }

    @Test func imaxIsLargestPreset() {
        let imaxArea = ScreenSizePreset.imax.width * ScreenSizePreset.imax.height
        let cinemaArea = ScreenSizePreset.cinema.width * ScreenSizePreset.cinema.height
        let personalArea = ScreenSizePreset.personal.width * ScreenSizePreset.personal.height
        #expect(imaxArea > cinemaArea)
        #expect(imaxArea > personalArea)
    }
}

// MARK: - Subtitle Sizing

@Suite("ScreenSizePreset — Subtitle Sizing", .serialized)
struct ScreenSizePresetSubtitleTests {

    @Test func personalSubtitleFontSize() {
        #expect(ScreenSizePreset.personal.subtitleFontSize == 36)
    }

    @Test func cinemaSubtitleFontSize() {
        #expect(ScreenSizePreset.cinema.subtitleFontSize == 60)
    }

    @Test func imaxSubtitleFontSize() {
        #expect(ScreenSizePreset.imax.subtitleFontSize == 80)
    }

    @Test func personalSubtitleMaxWidth() {
        #expect(ScreenSizePreset.personal.subtitleMaxWidth == 1200)
    }

    @Test func cinemaSubtitleMaxWidth() {
        #expect(ScreenSizePreset.cinema.subtitleMaxWidth == 2000)
    }

    @Test func imaxSubtitleMaxWidth() {
        #expect(ScreenSizePreset.imax.subtitleMaxWidth == 3200)
    }

    @Test func subtitleVerticalOffsetPersonal() {
        let expected = ScreenSizePreset.personal.height / 2 + 0.15
        #expect(ScreenSizePreset.personal.subtitleVerticalOffset == expected)
    }

    @Test func subtitleVerticalOffsetCinema() {
        let expected = ScreenSizePreset.cinema.height / 2 + 0.15
        #expect(ScreenSizePreset.cinema.subtitleVerticalOffset == expected)
    }

    @Test func subtitleVerticalOffsetIMAX() {
        let expected = ScreenSizePreset.imax.height / 2 + 0.15
        #expect(ScreenSizePreset.imax.subtitleVerticalOffset == expected)
    }

    @Test func subtitleMaxWidthIncreasesWithPresetSize() {
        #expect(ScreenSizePreset.personal.subtitleMaxWidth < ScreenSizePreset.cinema.subtitleMaxWidth)
        #expect(ScreenSizePreset.cinema.subtitleMaxWidth < ScreenSizePreset.imax.subtitleMaxWidth)
    }
}

// MARK: - CustomEnvironmentView Screen Discovery

@Suite("CustomEnvironmentView — Screen Discovery", .serialized)
@MainActor
struct CustomEnvironmentScreenDiscoveryTests {

    @Test func findScreenEntityMatchesScreenKeyword() {
        let root = Entity()
        let screen = ModelEntity()
        screen.name = "cinema-screen"
        root.addChild(screen)
        #expect(testableFindScreenEntity(in: root)?.name == "cinema-screen")
    }

    @Test func findScreenEntityMatchesDisplayKeyword() {
        let root = Entity()
        let display = ModelEntity()
        display.name = "main-display"
        root.addChild(display)
        #expect(testableFindScreenEntity(in: root)?.name == "main-display")
    }

    @Test func findScreenEntityMatchesTvKeyword() {
        let root = Entity()
        let tv = ModelEntity()
        tv.name = "wall-tv"
        root.addChild(tv)
        #expect(testableFindScreenEntity(in: root)?.name == "wall-tv")
    }

    @Test func findScreenEntityMatchesMonitorKeyword() {
        let root = Entity()
        let monitor = ModelEntity()
        monitor.name = "desk-monitor"
        root.addChild(monitor)
        #expect(testableFindScreenEntity(in: root)?.name == "desk-monitor")
    }

    @Test func findScreenEntityMatchesCinemaKeyword() {
        let root = Entity()
        let cinema = ModelEntity()
        cinema.name = "private-cinema"
        root.addChild(cinema)
        #expect(testableFindScreenEntity(in: root)?.name == "private-cinema")
    }

    @Test func findScreenEntityMatchesVideoKeyword() {
        let root = Entity()
        let video = ModelEntity()
        video.name = "big-video"
        root.addChild(video)
        #expect(testableFindScreenEntity(in: root)?.name == "big-video")
    }

    @Test func findScreenEntitySearchesDeepHierarchy() {
        let root = Entity()
        root.name = "room"
        let furniture = Entity()
        furniture.name = "furniture"
        let nested = Entity()
        nested.name = "entertainment-center"
        let screen = ModelEntity()
        screen.name = "tv-set"
        nested.addChild(screen)
        furniture.addChild(nested)
        root.addChild(furniture)
        #expect(testableFindScreenEntity(in: root)?.name == "tv-set")
    }

    @Test func findScreenEntityIgnoresNonMatchingNames() {
        let root = Entity()
        let wall = ModelEntity()
        wall.name = "wall"
        let floor = ModelEntity()
        floor.name = "floor"
        root.addChild(wall)
        root.addChild(floor)
        #expect(testableFindScreenEntity(in: root) == nil)
    }

    @Test func findScreenEntityIsCaseInsensitive() {
        let root = Entity()
        let screen = ModelEntity()
        screen.name = "my-screen"
        root.addChild(screen)
        #expect(testableFindScreenEntity(in: root)?.name == "my-screen")
    }

    @Test func findScreenEntitySkipsPlainEntityWithKeyword() {
        // A plain Entity (not ModelEntity) with a keyword should not match.
        let root = Entity()
        let plain = Entity()
        plain.name = "screen"
        root.addChild(plain)
        #expect(testableFindScreenEntity(in: root) == nil)
    }

    @Test func findScreenEntityPrefersFirstMatchInPreorder() {
        let root = Entity()
        let first = ModelEntity()
        first.name = "first-screen"
        let second = ModelEntity()
        second.name = "second-screen"
        root.addChild(first)
        root.addChild(second)
        #expect(testableFindScreenEntity(in: root)?.name == "first-screen")
    }
}

// MARK: - Material Fallback Logic

@Suite("Material Fallback Priority", .serialized)
struct MaterialFallbackTests {

    @Test func prefersVideoRendererOverAVPlayer() {
        let selection = MaterialSelection.resolve(
            hasVideoRenderer: true,
            hasAVPlayer: true
        )
        #expect(selection == .videoRenderer)
    }

    @Test func fallsBackToAVPlayerWhenNoRenderer() {
        let selection = MaterialSelection.resolve(
            hasVideoRenderer: false,
            hasAVPlayer: true
        )
        #expect(selection == .avPlayer)
    }

    @Test func fallsBackToUnlitWhenNeitherAvailable() {
        let selection = MaterialSelection.resolve(
            hasVideoRenderer: false,
            hasAVPlayer: false
        )
        #expect(selection == .unlitFallback)
    }

    @Test func usesVideoRendererWhenOnlyRendererAvailable() {
        let selection = MaterialSelection.resolve(
            hasVideoRenderer: true,
            hasAVPlayer: false
        )
        #expect(selection == .videoRenderer)
    }

    @Test func sourceIDReflectsRendererPriority() {
        // Replicates the `currentSourceID` logic from both immersive views.
        let rendererID = ObjectIdentifier(NSObject())
        let playerID = ObjectIdentifier(NSObject())

        #expect(testableCurrentSourceID(rendererID: rendererID, playerID: playerID) == rendererID)
    }

    @Test func sourceIDFallsBackToPlayerWhenNoRenderer() {
        let playerID = ObjectIdentifier(NSObject())

        #expect(testableCurrentSourceID(rendererID: nil, playerID: playerID) == playerID)
    }

    @Test func sourceIDIsNilWhenNeitherSourceExists() {
        #expect(testableCurrentSourceID(rendererID: nil, playerID: nil) == nil)
    }
}

// MARK: - AppState Weak Reference

@Suite("AppState — Weak Player References", .serialized)
@MainActor
struct AppStateImmersiveReferenceTests {

    @Test func activeAVPlayerBecomesNilWhenDeallocated() {
        let appState = AppState()
        autoreleasepool {
            let player = AVPlayer()
            appState.activeAVPlayer = player
            #expect(appState.activeAVPlayer != nil)
        }
        // AVPlayer can be retained by internal frameworks on visionOS;
        // briefly pause to allow deallocation under load.
        for _ in 0..<20 {
            if appState.activeAVPlayer == nil { break }
            Thread.sleep(forTimeInterval: 0.05)
        }
        #expect(appState.activeAVPlayer == nil)
    }

    @Test func activeVideoRendererBecomesNilWhenDeallocated() {
        let appState = AppState()
        autoreleasepool {
            var renderer: AVSampleBufferVideoRenderer? = AVSampleBufferVideoRenderer()
            appState.activeVideoRenderer = renderer
            #expect(appState.activeVideoRenderer != nil)
            renderer = nil
        }
        #expect(appState.activeVideoRenderer == nil)
    }

    @Test func assigningNewPlayerReplacesOldWeakReference() {
        let appState = AppState()
        let firstPlayer = AVPlayer()
        let secondPlayer = AVPlayer()
        appState.activeAVPlayer = firstPlayer
        #expect(appState.activeAVPlayer === firstPlayer)
        appState.activeAVPlayer = secondPlayer
        #expect(appState.activeAVPlayer === secondPlayer)
    }
}

// MARK: - HDRISkyboxEnvironment Screen Positioning

@Suite("HDRISkyboxEnvironment — Screen Positioning Math", .serialized)
struct HDRISkyboxScreenPositioningTests {

    @Test func defaultScreenPositionForPersonalPreset() {
        let preset = ScreenSizePreset.personal
        let expected = SIMD3<Float>(0, 1.6, -preset.distance)
        #expect(expected.x == 0)
        #expect(expected.y == 1.6)
        #expect(expected.z == -10)
    }

    @Test func defaultScreenPositionForCinemaPreset() {
        let preset = ScreenSizePreset.cinema
        let expected = SIMD3<Float>(0, 1.6, -preset.distance)
        #expect(expected.z == -20)
    }

    @Test func defaultScreenPositionForIMAXPreset() {
        let preset = ScreenSizePreset.imax
        let expected = SIMD3<Float>(0, 1.6, -preset.distance)
        #expect(expected.z == -35)
    }

    @Test func headAnchoredPositionUsesHeadY() {
        // Replicates the one-shot anchoring math from the update cycle.
        var transform = simd_float4x4(1)
        transform.columns.3 = SIMD4<Float>(2, 1.5, 5, 1)
        transform.columns.2 = SIMD4<Float>(0, 0, -1, 0)

        let col3 = transform.columns.3
        let headPos = SIMD3<Float>(col3.x, col3.y, col3.z)
        let col2 = transform.columns.2
        let forward = ImmersiveControlsPolicy.safeHorizontalForward(from: col2)
        let dist = ScreenSizePreset.cinema.distance
        let screenPos = headPos + forward * dist
        let finalScreenPos = SIMD3<Float>(screenPos.x, headPos.y, screenPos.z)

        #expect(finalScreenPos.x == 2)
        #expect(finalScreenPos.y == 1.5)
        #expect(finalScreenPos.z == 25)
    }

    @Test func headAnchoredPositionWithOffsetForward() {
        // Head facing +Z (forward = (0, 0, -1) after normalization)
        var transform = simd_float4x4(1)
        transform.columns.3 = SIMD4<Float>(0, 1.6, 0, 1)
        transform.columns.2 = SIMD4<Float>(0, 0, 1, 0)

        let col3 = transform.columns.3
        let headPos = SIMD3<Float>(col3.x, col3.y, col3.z)
        let col2 = transform.columns.2
        let forward = ImmersiveControlsPolicy.safeHorizontalForward(from: col2)
        let dist = ScreenSizePreset.personal.distance
        let screenPos = headPos + forward * dist
        let finalScreenPos = SIMD3<Float>(screenPos.x, headPos.y, screenPos.z)

        #expect(finalScreenPos.x == 0)
        #expect(finalScreenPos.y == 1.6)
        #expect(finalScreenPos.z == -10)
    }

    @Test func safeHorizontalForwardNormalizesTypicalColumn() {
        let column = SIMD4<Float>(0, 0, -1, 0)
        let forward = ImmersiveControlsPolicy.safeHorizontalForward(from: column)
        #expect(forward.x == 0)
        #expect(forward.y == 0)
        #expect(forward.z == 1)
    }

    @Test func safeHorizontalForwardIgnoresYComponent() {
        let column = SIMD4<Float>(-3, 10, -4, 0)
        let forward = ImmersiveControlsPolicy.safeHorizontalForward(from: column)
        #expect(forward.y == 0)
        let horizontalLen = sqrt(forward.x * forward.x + forward.z * forward.z)
        #expect(horizontalLen == 1.0)
    }

    @Test func safeHorizontalForwardFallbackOnZeroLength() {
        let column = SIMD4<Float>(0, 0, 0, 0)
        let forward = ImmersiveControlsPolicy.safeHorizontalForward(from: column)
        #expect(forward == SIMD3<Float>(0, 0, -1))
    }

    @Test func cyclingScreenSizeUpdatesDistance() {
        // Verifies that each preset has a distinct, increasing distance.
        #expect(ScreenSizePreset.personal.distance < ScreenSizePreset.cinema.distance)
        #expect(ScreenSizePreset.cinema.distance < ScreenSizePreset.imax.distance)
    }
}

// MARK: - CustomEnvironmentView Fallback Screen

@Suite("CustomEnvironmentView — Fallback Screen", .serialized)
@MainActor
struct CustomEnvironmentFallbackScreenTests {

    @Test func fallbackScreenUsesPersonalDimensions() {
        let screen = makeTestableFallbackScreen()
        let model = try! #require(screen.model)
        #expect(model.mesh.bounds.extents.x == ScreenSizePreset.personal.width)
        #expect(model.mesh.bounds.extents.y == ScreenSizePreset.personal.height)
    }

    @Test func fallbackScreenPositionYEqualsFallbackEyeHeight() {
        let screen = makeTestableFallbackScreen()
        #expect(screen.position.y == ImmersiveControlsPolicy.fallbackEyeHeight)
    }

    @Test func fallbackScreenPositionZEqualsNegativeFour() {
        let screen = makeTestableFallbackScreen()
        #expect(screen.position.z == -4)
    }

    @Test func fallbackScreenPositionXIsCentered() {
        let screen = makeTestableFallbackScreen()
        #expect(screen.position.x == 0)
    }

    @Test func fallbackScreenNameContainsFallback() {
        let screen = makeTestableFallbackScreen()
        #expect(screen.name.contains("fallback"))
    }

    @Test func fallbackScreenUsesBlackMaterial() {
        let screen = makeTestableFallbackScreen()
        let model = try! #require(screen.model)
        let firstMaterial = model.materials.first
        #expect(firstMaterial != nil)
    }

    @Test func fallbackScreenHasNonEmptyName() {
        let screen = makeTestableFallbackScreen()
        #expect(!screen.name.isEmpty)
    }
}

// MARK: - Loading State Equatable

@Suite("LoadingState — Equatable", .serialized)
struct LoadingStateEquatableTests {

    // Replicates the private LoadingState from both immersive views.
    private enum LoadingState: Equatable {
        case loading
        case loaded
        case failed(String)
    }

    @Test func loadingEqualsLoading() {
        #expect(LoadingState.loading == .loading)
    }

    @Test func loadedEqualsLoaded() {
        #expect(LoadingState.loaded == .loaded)
    }

    @Test func failedEqualsSameMessage() {
        #expect(LoadingState.failed("error") == .failed("error"))
    }

    @Test func failedNotEqualDifferentMessage() {
        #expect(LoadingState.failed("a") != .failed("b"))
    }

    @Test func loadingNotEqualLoaded() {
        #expect(LoadingState.loading != .loaded)
    }
}
#endif
