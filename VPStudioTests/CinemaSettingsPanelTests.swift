#if os(visionOS)
import Foundation
import SwiftUI
import Testing
import simd
@testable import VPStudio

// MARK: - Test Helpers

/// Replicates the seat-offset binding logic from `CinemaSettingsPanel` so it can be verified
/// independently of the private view implementation.
@MainActor
struct CinemaSettingsPanelBindingHelper {
    static func seatXBinding(for settings: CinemaSettings) -> Binding<Double> {
        Binding(
            get: { settings.seatOffset.x },
            set: { settings.seatOffset.x = $0 }
        )
    }

    static func seatYBinding(for settings: CinemaSettings) -> Binding<Double> {
        Binding(
            get: { settings.seatOffset.y },
            set: { settings.seatOffset.y = $0 }
        )
    }

    static func seatZBinding(for settings: CinemaSettings) -> Binding<Double> {
        Binding(
            get: { settings.seatOffset.z },
            set: { settings.seatOffset.z = $0 }
        )
    }

    /// Replicates the screen-size display string produced by the panel.
    static func screenSizeDisplay(for settings: CinemaSettings) -> String {
        String(
            format: "%.2f × %.2f m",
            settings.screenSize.width,
            settings.screenSize.height
        )
    }

    /// Replicates the offset stepper label produced by `offsetStepper`.
    static func offsetStepperLabel(axis: String, value: Double) -> String {
        String(format: "%@: %.1f m", axis, value)
    }
}

// MARK: - CinemaSettingsPanel Tests

@Suite("CinemaSettingsPanel")
@MainActor
struct CinemaSettingsPanelTests {
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

    // MARK: - Initialization

    @Test("panel stores the provided settings reference")
    func initializationStoresSettings() async throws {
        let settings = CinemaSettings(loadPersisted: false)
        let panel = CinemaSettingsPanel(settings: settings)
        #expect(panel.settings === settings)
    }

    @Test("panel reflects initial preset via settings")
    func initializationReflectsPreset() async throws {
        let settings = CinemaSettings(preset: .imax, baseAspectRatio: 16.0 / 9.0)
        let panel = CinemaSettingsPanel(settings: settings)
        #expect(panel.settings.activePreset == .imax)
        #expect(panel.settings.screenWidth == 10.0)
    }

    // MARK: - Bindings Propagation

    @Test("mutating screenWidth through settings propagates to panel")
    func screenWidthBindingPropagation() async throws {
        let settings = CinemaSettings(loadPersisted: false)
        let panel = CinemaSettingsPanel(settings: settings)
        panel.settings.screenWidth = 8.5
        #expect(panel.settings.screenWidth == 8.5)
    }

    @Test("mutating screenDistance through settings propagates to panel")
    func screenDistanceBindingPropagation() async throws {
        let settings = CinemaSettings(loadPersisted: false)
        let panel = CinemaSettingsPanel(settings: settings)
        panel.settings.screenDistance = 12.0
        #expect(panel.settings.screenDistance == 12.0)
    }

    @Test("mutating screenHeight through settings propagates to panel")
    func screenHeightBindingPropagation() async throws {
        let settings = CinemaSettings(loadPersisted: false)
        let panel = CinemaSettingsPanel(settings: settings)
        panel.settings.screenHeight = 2.5
        #expect(panel.settings.screenHeight == 2.5)
    }

    @Test("mutating screenTilt through settings propagates to panel")
    func screenTiltBindingPropagation() async throws {
        let settings = CinemaSettings(loadPersisted: false)
        let panel = CinemaSettingsPanel(settings: settings)
        panel.settings.screenTilt = -10.0
        #expect(panel.settings.screenTilt == -10.0)
    }

    @Test("mutating environmentDarkness through settings propagates to panel")
    func environmentDarknessBindingPropagation() async throws {
        let settings = CinemaSettings(loadPersisted: false)
        let panel = CinemaSettingsPanel(settings: settings)
        panel.settings.environmentDarkness = 0.35
        #expect(panel.settings.environmentDarkness == 0.35)
    }

    @Test("mutating ambientLighting through settings propagates to panel")
    func ambientLightingBindingPropagation() async throws {
        let settings = CinemaSettings(loadPersisted: false)
        let panel = CinemaSettingsPanel(settings: settings)
        panel.settings.ambientLighting = 0.75
        #expect(panel.settings.ambientLighting == 0.75)
    }

    @Test("mutating useSurroundingsEffect through settings propagates to panel")
    func useSurroundingsEffectBindingPropagation() async throws {
        let settings = CinemaSettings(loadPersisted: false)
        let panel = CinemaSettingsPanel(settings: settings)
        panel.settings.useSurroundingsEffect = false
        #expect(panel.settings.useSurroundingsEffect == false)
    }

    @Test("mutating immersionStyleRaw through settings propagates to panel")
    func immersionStyleRawBindingPropagation() async throws {
        let settings = CinemaSettings(loadPersisted: false)
        let panel = CinemaSettingsPanel(settings: settings)
        panel.settings.immersionStyleRaw = CinemaImmersionStyle.progressive.rawValue
        #expect(panel.settings.immersionStyle == .progressive)
    }

    // MARK: - Seat Offset Bindings (mirroring panel logic)

    @Test("seatX binding reads and writes seatOffset.x")
    func seatXBinding() async throws {
        let settings = CinemaSettings(seatOffset: SIMD3(0.5, 0, 0), loadPersisted: false)
        let binding = CinemaSettingsPanelBindingHelper.seatXBinding(for: settings)
        #expect(binding.wrappedValue == 0.5)
        binding.wrappedValue = -1.2
        #expect(settings.seatOffset.x == -1.2)
    }

    @Test("seatY binding reads and writes seatOffset.y")
    func seatYBinding() async throws {
        let settings = CinemaSettings(seatOffset: SIMD3(0, -0.3, 0), loadPersisted: false)
        let binding = CinemaSettingsPanelBindingHelper.seatYBinding(for: settings)
        #expect(binding.wrappedValue == -0.3)
        binding.wrappedValue = 1.5
        #expect(settings.seatOffset.y == 1.5)
    }

    @Test("seatZ binding reads and writes seatOffset.z")
    func seatZBinding() async throws {
        let settings = CinemaSettings(seatOffset: SIMD3(0, 0, 0.8), loadPersisted: false)
        let binding = CinemaSettingsPanelBindingHelper.seatZBinding(for: settings)
        #expect(binding.wrappedValue == 0.8)
        binding.wrappedValue = -1.9
        #expect(settings.seatOffset.z == -1.9)
    }

    @Test("seat offset bindings are independent per axis")
    func seatOffsetBindingsIndependence() async throws {
        let settings = CinemaSettings(seatOffset: .zero, loadPersisted: false)
        let x = CinemaSettingsPanelBindingHelper.seatXBinding(for: settings)
        let y = CinemaSettingsPanelBindingHelper.seatYBinding(for: settings)
        let z = CinemaSettingsPanelBindingHelper.seatZBinding(for: settings)
        x.wrappedValue = 1.0
        y.wrappedValue = 2.0
        z.wrappedValue = 3.0
        #expect(settings.seatOffset == SIMD3(1.0, 2.0, 3.0))
    }

    // MARK: - Preset Picker

    @Test("preset picker updates settings to frontRow")
    func presetPickerFrontRow() async throws {
        let settings = CinemaSettings(preset: .default, baseAspectRatio: 16.0 / 9.0)
        let panel = CinemaSettingsPanel(settings: settings)
        panel.settings.activePreset = .frontRow
        #expect(panel.settings.activePreset == .frontRow)
        #expect(panel.settings.screenWidth == 5.0)
        #expect(panel.settings.screenDistance == 2.5)
    }

    @Test("preset picker updates settings to backRow")
    func presetPickerBackRow() async throws {
        let settings = CinemaSettings(preset: .default, baseAspectRatio: 16.0 / 9.0)
        let panel = CinemaSettingsPanel(settings: settings)
        panel.settings.activePreset = .backRow
        #expect(panel.settings.activePreset == .backRow)
        #expect(panel.settings.screenDistance == 8.0)
        #expect(panel.settings.immersionStyle == .progressive)
    }

    @Test("preset picker updates settings to imax")
    func presetPickerImax() async throws {
        let settings = CinemaSettings(preset: .default, baseAspectRatio: 16.0 / 9.0)
        let panel = CinemaSettingsPanel(settings: settings)
        panel.settings.activePreset = .imax
        #expect(panel.settings.activePreset == .imax)
        #expect(panel.settings.screenWidth == 10.0)
    }

    @Test("preset picker updates settings to custom")
    func presetPickerCustom() async throws {
        let settings = CinemaSettings(preset: .default, baseAspectRatio: 16.0 / 9.0)
        let panel = CinemaSettingsPanel(settings: settings)
        panel.settings.screenWidth = 7.7
        #expect(panel.settings.activePreset == .custom)
    }

    @Test("preset picker omits custom no-op preset")
    func presetPickerOmitsCustomNoOpPreset() throws {
        let source = try contents(of: "VPStudio/Views/Immersive/Cinema/CinemaSettingsPanel.swift")
        #expect(source.contains("ForEach(CinemaPreset.selectablePresets)"))
        #expect(!source.contains("ForEach(CinemaPreset.allCases)"))
        #expect(source.contains(#"Label("Custom settings", systemImage: "slider.horizontal.3")"#))
    }

    // MARK: - Action Buttons

    @Test("save button persists current values")
    func saveButton() async throws {
        let defs = UserDefaults.standard
        let key = "CinemaEnvironment.screenDistance"
        let previous = defs.object(forKey: key)
        defer {
            if let previous { defs.set(previous, forKey: key) }
            else { defs.removeObject(forKey: key) }
        }

        let settings = CinemaSettings(screenDistance: 7.5, loadPersisted: false)
        let panel = CinemaSettingsPanel(settings: settings)
        panel.settings.save()
        #expect(defs.double(forKey: key) == 7.5)
    }

    @Test("reset to preset button applies active preset with current aspect ratio")
    func resetToPresetButton() async throws {
        let settings = CinemaSettings(preset: .frontRow, baseAspectRatio: 16.0 / 9.0)
        settings.screenWidth = 2.0
        settings.screenDistance = 1.0
        let panel = CinemaSettingsPanel(settings: settings)
        // Explicitly apply frontRow preset since activePreset is now .custom after mutations
        panel.settings.apply(
            preset: .frontRow,
            baseAspectRatio: panel.settings.videoAspectRatio
        )
        #expect(panel.settings.screenWidth == 5.0)
        #expect(panel.settings.screenDistance == 2.5)
        #expect(panel.settings.videoAspectRatio == 16.0 / 9.0)
    }

    @Test("reset to preset action is guarded for custom layouts")
    func resetToPresetActionGuardedForCustomLayouts() throws {
        let source = try contents(of: "VPStudio/Views/Immersive/Cinema/CinemaSettingsPanel.swift")
        #expect(source.contains("guard CinemaPreset.selectablePresets.contains(activePreset) else { return }"))
        #expect(source.contains(".disabled(!CinemaPreset.selectablePresets.contains(activePreset))"))
    }

    // MARK: - Comfort Warning Logic

    @Test("comfort warning is shown for default settings")
    func comfortWarningDefault() async throws {
        let settings = CinemaSettings(loadPersisted: false)
        let panel = CinemaSettingsPanel(settings: settings)
        #expect(panel.settings.isComfortable == false)
    }

    @Test("comfort warning is hidden for comfortable configuration")
    func comfortWarningHidden() async throws {
        // width=3.0, distance=4.0 → FOV ≈ 36.9° ≤ 60°
        let settings = CinemaSettings(screenWidth: 3.0, screenDistance: 4.0, loadPersisted: false)
        let panel = CinemaSettingsPanel(settings: settings)
        #expect(panel.settings.isComfortable == true)
    }

    @Test("comfort warning is shown for very close large screen")
    func comfortWarningCloseLargeScreen() async throws {
        let settings = CinemaSettings(screenWidth: 8.0, screenDistance: 1.2, loadPersisted: false)
        let panel = CinemaSettingsPanel(settings: settings)
        #expect(panel.settings.isComfortable == false)
    }

    @Test("comfort warning is shown for close small screen with high FOV")
    func comfortWarningCloseSmallScreen() async throws {
        // width=1.5, distance=1.2 → FOV ≈ 64° > 60°, so NOT comfortable
        let settings = CinemaSettings(screenWidth: 1.5, screenDistance: 1.2, loadPersisted: false)
        let panel = CinemaSettingsPanel(settings: settings)
        #expect(panel.settings.isComfortable == false)
    }

    @Test("comfort warning updates when screenWidth changes")
    func comfortWarningUpdatesOnWidthChange() async throws {
        let settings = CinemaSettings(screenWidth: 3.0, screenDistance: 4.0, loadPersisted: false)
        let panel = CinemaSettingsPanel(settings: settings)
        #expect(panel.settings.isComfortable == true)
        panel.settings.screenWidth = 12.0
        #expect(panel.settings.isComfortable == false)
    }

    // MARK: - FOV & Screen Size Display Formatting

    @Test("screen size display formats width and height to two decimals")
    func screenSizeDisplayFormatting() async throws {
        let settings = CinemaSettings(screenWidth: 6.0, videoAspectRatio: 16.0 / 9.0, loadPersisted: false)
        let display = CinemaSettingsPanelBindingHelper.screenSizeDisplay(for: settings)
        #expect(display == "6.00 × 3.38 m")
    }

    @Test("screen size display with 4:3 aspect ratio")
    func screenSizeDisplay4By3() async throws {
        let settings = CinemaSettings(screenWidth: 4.0, videoAspectRatio: 4.0 / 3.0, loadPersisted: false)
        let display = CinemaSettingsPanelBindingHelper.screenSizeDisplay(for: settings)
        #expect(display == "4.00 × 3.00 m")
    }

    @Test("horizontal FOV within expected range for default settings")
    func horizontalFOVDefault() async throws {
        let settings = CinemaSettings(screenWidth: 6.0, screenDistance: 4.0, loadPersisted: false)
        let panel = CinemaSettingsPanel(settings: settings)
        let fov = panel.settings.horizontalFOV
        #expect(fov > 70.0 && fov < 75.0)
    }

    @Test("horizontal FOV approaches zero for tiny width")
    func horizontalFOVTinyWidth() async throws {
        let settings = CinemaSettings(screenWidth: 0.01, screenDistance: 4.0, loadPersisted: false)
        let panel = CinemaSettingsPanel(settings: settings)
        #expect(panel.settings.horizontalFOV < 1.0)
    }

    // MARK: - Slider Range Validation

    @Test("screenWidth slider range is 1 to 10")
    func screenWidthSliderRange() async throws {
        let settings = CinemaSettings(loadPersisted: false)
        let panel = CinemaSettingsPanel(settings: settings)
        #expect(panel.settings.screenWidth >= 1.0)
        #expect(panel.settings.screenWidth <= 10.0)
    }

    @Test("screenDistance slider range is 1.5 to 15")
    func screenDistanceSliderRange() async throws {
        let settings = CinemaSettings(loadPersisted: false)
        let panel = CinemaSettingsPanel(settings: settings)
        #expect(panel.settings.screenDistance >= 1.5)
        #expect(panel.settings.screenDistance <= 15.0)
    }

    @Test("screenHeight slider range is -2 to 4")
    func screenHeightSliderRange() async throws {
        let settings = CinemaSettings(loadPersisted: false)
        let panel = CinemaSettingsPanel(settings: settings)
        #expect(panel.settings.screenHeight >= -2.0)
        #expect(panel.settings.screenHeight <= 4.0)
    }

    @Test("screenTilt slider range is -15 to 15")
    func screenTiltSliderRange() async throws {
        let settings = CinemaSettings(loadPersisted: false)
        let panel = CinemaSettingsPanel(settings: settings)
        #expect(panel.settings.screenTilt >= -15.0)
        #expect(panel.settings.screenTilt <= 15.0)
    }

    @Test("environmentDarkness slider range is 0 to 1")
    func environmentDarknessSliderRange() async throws {
        let settings = CinemaSettings(loadPersisted: false)
        let panel = CinemaSettingsPanel(settings: settings)
        #expect(panel.settings.environmentDarkness >= 0.0)
        #expect(panel.settings.environmentDarkness <= 1.0)
    }

    @Test("ambientLighting slider range is 0 to 1")
    func ambientLightingSliderRange() async throws {
        let settings = CinemaSettings(loadPersisted: false)
        let panel = CinemaSettingsPanel(settings: settings)
        #expect(panel.settings.ambientLighting >= 0.0)
        #expect(panel.settings.ambientLighting <= 1.0)
    }

    // MARK: - Offset Stepper Labels

    @Test("offset stepper label formatting for positive value")
    func offsetStepperLabelPositive() async throws {
        let label = CinemaSettingsPanelBindingHelper.offsetStepperLabel(axis: "X", value: 1.25)
        #expect(label == "X: 1.2 m")
    }

    @Test("offset stepper label formatting for negative value")
    func offsetStepperLabelNegative() async throws {
        let label = CinemaSettingsPanelBindingHelper.offsetStepperLabel(axis: "Y", value: -0.75)
        #expect(label == "Y: -0.8 m")
    }

    // MARK: - Immersion Style Picker

    @Test("immersion style picker options include all cases")
    func immersionStylePickerOptions() async throws {
        let styles = CinemaImmersionStyle.allCases
        #expect(styles.count == 3)
        #expect(styles.contains(.mixed))
        #expect(styles.contains(.full))
        #expect(styles.contains(.progressive))
    }

    @Test("immersion style picker updates raw value")
    func immersionStylePickerUpdates() async throws {
        let settings = CinemaSettings(immersionStyle: .full, loadPersisted: false)
        let panel = CinemaSettingsPanel(settings: settings)
        panel.settings.immersionStyle = .mixed
        #expect(panel.settings.immersionStyleRaw == CinemaImmersionStyle.mixed.rawValue)
    }

    // MARK: - Panel Lifecycle & Derived Consistency

    @Test("panel screenSize is consistent with width and aspect ratio")
    func panelScreenSizeConsistency() async throws {
        let settings = CinemaSettings(screenWidth: 8.0, videoAspectRatio: 2.0, loadPersisted: false)
        let panel = CinemaSettingsPanel(settings: settings)
        #expect(panel.settings.screenSize.width == 8.0)
        #expect(panel.settings.screenSize.height == 4.0)
    }

    @Test("panel preserves custom values after custom preset selection")
    func panelPreservesCustomValues() async throws {
        let settings = CinemaSettings(loadPersisted: false)
        let panel = CinemaSettingsPanel(settings: settings)
        panel.settings.screenWidth = 7.2
        panel.settings.screenDistance = 5.5
        panel.settings.activePreset = .custom
        #expect(panel.settings.screenWidth == 7.2)
        #expect(panel.settings.screenDistance == 5.5)
    }

    @Test("panel resets all geometry values when switching from custom to default preset")
    func panelResetFromCustomToDefault() async throws {
        let settings = CinemaSettings(loadPersisted: false)
        let panel = CinemaSettingsPanel(settings: settings)
        panel.settings.screenWidth = 9.9
        panel.settings.screenDistance = 14.0
        panel.settings.screenHeight = 3.9
        panel.settings.screenTilt = -14.0
        panel.settings.activePreset = .default
        #expect(panel.settings.screenWidth == 6.0)
        #expect(panel.settings.screenDistance == 4.0)
        #expect(panel.settings.screenHeight == 0.0)
        #expect(panel.settings.screenTilt == 0.0)
    }

    @Test("panel surroundings effect toggle flips boolean")
    func surroundingsEffectToggle() async throws {
        let settings = CinemaSettings(useSurroundingsEffect: true, loadPersisted: false)
        let panel = CinemaSettingsPanel(settings: settings)
        panel.settings.useSurroundingsEffect.toggle()
        #expect(panel.settings.useSurroundingsEffect == false)
    }

    @Test("panel seat offset within stepper range")
    func seatOffsetWithinStepperRange() async throws {
        let settings = CinemaSettings(seatOffset: SIMD3(1.5, -1.5, 0.5), loadPersisted: false)
        let panel = CinemaSettingsPanel(settings: settings)
        #expect(panel.settings.seatOffset.x >= -2.0 && panel.settings.seatOffset.x <= 2.0)
        #expect(panel.settings.seatOffset.y >= -2.0 && panel.settings.seatOffset.y <= 2.0)
        #expect(panel.settings.seatOffset.z >= -2.0 && panel.settings.seatOffset.z <= 2.0)
    }
}
#endif
