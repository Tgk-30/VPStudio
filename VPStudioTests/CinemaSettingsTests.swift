#if os(visionOS)
import Foundation
import Testing
import simd
@testable import VPStudio

@Suite("CinemaSettings")
@MainActor
struct CinemaSettingsTests {

    // MARK: - Helpers

    private func clearCinemaDefaults() {
        let defs = UserDefaults.standard
        let keys: [String] = [
            "CinemaEnvironment.screenWidth",
            "CinemaEnvironment.screenDistance",
            "CinemaEnvironment.screenHeight",
            "CinemaEnvironment.screenTilt",
            "CinemaEnvironment.seatOffsetX",
            "CinemaEnvironment.seatOffsetY",
            "CinemaEnvironment.seatOffsetZ",
            "CinemaEnvironment.environmentDarkness",
            "CinemaEnvironment.ambientLighting",
            "CinemaEnvironment.immersionStyle",
            "CinemaEnvironment.useSurroundingsEffect",
            "CinemaEnvironment.videoAspectRatio",
            SettingsKeys.cinemaAutoDimOnPlay,
        ]
        for key in keys {
            defs.removeObject(forKey: key)
        }
    }

    // MARK: - Initialization

    @Test("default initialization values")
    func defaultInitialization() async throws {
        let settings = CinemaSettings(loadPersisted: false)
        #expect(settings.screenWidth == 6.0)
        #expect(settings.screenDistance == 4.0)
        #expect(settings.screenHeight == 0.0)
        #expect(settings.screenTilt == 0.0)
        #expect(settings.seatOffset == SIMD3<Double>.zero)
        #expect(settings.environmentDarkness == 0.8)
        #expect(settings.ambientLighting == 0.1)
        #expect(settings.immersionStyleRaw == CinemaImmersionStyle.full.rawValue)
        #expect(settings.useSurroundingsEffect == true)
        #expect(settings.autoDimOnPlay == true)
        #expect(settings.videoAspectRatio == 16.0 / 9.0)
    }

    @Test("custom initialization values")
    func customInitialization() async throws {
        let settings = CinemaSettings(
            screenWidth: 10.0,
            screenDistance: 5.0,
            screenHeight: 1.0,
            screenTilt: 5.0,
            seatOffset: SIMD3(1, 2, 3),
            environmentDarkness: 0.5,
            ambientLighting: 0.2,
            immersionStyle: .progressive,
            useSurroundingsEffect: false,
            videoAspectRatio: 2.39,
            loadPersisted: false
        )
        #expect(settings.screenWidth == 10.0)
        #expect(settings.screenDistance == 5.0)
        #expect(settings.screenHeight == 1.0)
        #expect(settings.screenTilt == 5.0)
        #expect(settings.seatOffset == SIMD3(1, 2, 3))
        #expect(settings.environmentDarkness == 0.5)
        #expect(settings.ambientLighting == 0.2)
        #expect(settings.immersionStyle == .progressive)
        #expect(settings.useSurroundingsEffect == false)
        #expect(settings.videoAspectRatio == 2.39)
    }

    @Test("convenience init from default preset")
    func convenienceInitDefaultPreset() async throws {
        let settings = CinemaSettings(preset: .default, baseAspectRatio: 16.0 / 9.0)
        #expect(settings.screenWidth == 6.0)
        #expect(settings.screenDistance == 4.0)
        #expect(settings.screenHeight == 0.0)
        #expect(settings.screenTilt == 0.0)
        #expect(settings.seatOffset == .zero)
        #expect(settings.environmentDarkness == 0.8)
        #expect(settings.ambientLighting == 0.1)
        #expect(settings.immersionStyle == .full)
        #expect(settings.useSurroundingsEffect == true)
    }

    @Test("convenience init from frontRow preset")
    func convenienceInitFrontRowPreset() async throws {
        let settings = CinemaSettings(preset: .frontRow, baseAspectRatio: 16.0 / 9.0)
        #expect(settings.screenWidth == 5.0)
        #expect(settings.screenDistance == 2.5)
        #expect(settings.screenHeight == -0.3)
        #expect(settings.screenTilt == 5.0)
        #expect(settings.seatOffset == .zero)
        #expect(settings.environmentDarkness == 1.0)
        #expect(settings.ambientLighting == 0.05)
        #expect(settings.immersionStyle == .full)
        #expect(settings.useSurroundingsEffect == true)
    }

    @Test("convenience init from backRow preset")
    func convenienceInitBackRowPreset() async throws {
        let settings = CinemaSettings(preset: .backRow, baseAspectRatio: 16.0 / 9.0)
        #expect(settings.screenWidth == 4.5)
        #expect(settings.screenDistance == 8.0)
        #expect(settings.screenHeight == 0.5)
        #expect(settings.screenTilt == -3.0)
        #expect(settings.seatOffset == .zero)
        #expect(settings.environmentDarkness == 0.6)
        #expect(settings.ambientLighting == 0.2)
        #expect(settings.immersionStyle == .progressive)
        #expect(settings.useSurroundingsEffect == false)
    }

    @Test("convenience init from imax preset")
    func convenienceInitImaxPreset() async throws {
        let settings = CinemaSettings(preset: .imax, baseAspectRatio: 16.0 / 9.0)
        #expect(settings.screenWidth == 10.0)
        #expect(settings.screenDistance == 3.5)
        #expect(settings.screenHeight == 1.0)
        #expect(settings.screenTilt == 8.0)
        #expect(settings.seatOffset == SIMD3(0, 0.1, 0))
        #expect(settings.environmentDarkness == 1.0)
        #expect(settings.ambientLighting == 0.0)
        #expect(settings.immersionStyle == .full)
        #expect(settings.useSurroundingsEffect == true)
    }

    @Test("convenience init from custom preset")
    func convenienceInitCustomPreset() async throws {
        let settings = CinemaSettings(preset: .custom, baseAspectRatio: 2.0)
        // Should retain default init values since apply(.custom) is a no-op
        #expect(settings.screenWidth == 6.0)
        #expect(settings.screenDistance == 4.0)
        #expect(settings.videoAspectRatio == 2.0)
    }

    // MARK: - Screen Size

    @Test("screenSize with 16:9 aspect ratio")
    func screenSize16By9() async throws {
        let settings = CinemaSettings(screenWidth: 16.0, videoAspectRatio: 16.0 / 9.0, loadPersisted: false)
        let size = settings.screenSize
        #expect(size.width == 16.0)
        #expect(size.height == 9.0)
    }

    @Test("screenSize with 4:3 aspect ratio")
    func screenSize4By3() async throws {
        let settings = CinemaSettings(screenWidth: 4.0, videoAspectRatio: 4.0 / 3.0, loadPersisted: false)
        let size = settings.screenSize
        #expect(size.width == 4.0)
        #expect(size.height == 3.0)
    }

    @Test("screenSize with ultrawide 21:9 aspect ratio")
    func screenSize21By9() async throws {
        let settings = CinemaSettings(screenWidth: 21.0, videoAspectRatio: 21.0 / 9.0, loadPersisted: false)
        let size = settings.screenSize
        #expect(size.width == 21.0)
        #expect(size.height == 9.0)
    }

    @Test("screenSize updates when videoAspectRatio changes")
    func screenSizeUpdatesOnAspectRatioChange() async throws {
        let settings = CinemaSettings(screenWidth: 16.0, videoAspectRatio: 16.0 / 9.0, loadPersisted: false)
        #expect(settings.screenSize.height == 9.0)
        settings.videoAspectRatio = 2.0
        #expect(settings.screenSize.height == 8.0)
    }

    @Test("screenSize with very large aspect ratio")
    func screenSizeVeryLargeAspectRatio() async throws {
        let settings = CinemaSettings(screenWidth: 10.0, videoAspectRatio: 100.0, loadPersisted: false)
        let size = settings.screenSize
        #expect(size.width == 10.0)
        #expect(size.height == 0.1)
    }

    @Test("screenSize with very small aspect ratio")
    func screenSizeVerySmallAspectRatio() async throws {
        let settings = CinemaSettings(screenWidth: 10.0, videoAspectRatio: 0.01, loadPersisted: false)
        let size = settings.screenSize
        #expect(size.width == 10.0)
        #expect(size.height == 1000.0)
    }

    @Test("screenSize with zero aspect ratio produces infinite height")
    func screenSizeZeroAspectRatio() async throws {
        let settings = CinemaSettings(screenWidth: 10.0, videoAspectRatio: 0.0, loadPersisted: false)
        let size = settings.screenSize
        #expect(size.width == 10.0)
        #expect(size.height.isInfinite)
    }

    @Test("screenSize with negative aspect ratio")
    func screenSizeNegativeAspectRatio() async throws {
        let settings = CinemaSettings(screenWidth: 10.0, videoAspectRatio: -2.0, loadPersisted: false)
        let size = settings.screenSize
        #expect(size.width == 10.0)
        #expect(size.height == -5.0)
    }

    // MARK: - Immersion Style

    @Test("immersionStyle getter returns full for valid raw value")
    func immersionStyleGetterValid() async throws {
        let settings = CinemaSettings(immersionStyle: .full, loadPersisted: false)
        #expect(settings.immersionStyle == .full)
    }

    @Test("immersionStyle getter returns full for invalid raw value")
    func immersionStyleGetterInvalid() async throws {
        let settings = CinemaSettings(loadPersisted: false)
        settings.immersionStyleRaw = "invalid"
        #expect(settings.immersionStyle == .full)
    }

    @Test("immersionStyle setter updates raw value to mixed")
    func immersionStyleSetterMixed() async throws {
        let settings = CinemaSettings(loadPersisted: false)
        settings.immersionStyle = .mixed
        #expect(settings.immersionStyleRaw == CinemaImmersionStyle.mixed.rawValue)
    }

    @Test("immersionStyle setter updates raw value to progressive")
    func immersionStyleSetterProgressive() async throws {
        let settings = CinemaSettings(loadPersisted: false)
        settings.immersionStyle = .progressive
        #expect(settings.immersionStyleRaw == CinemaImmersionStyle.progressive.rawValue)
    }

    @Test("immersionStyle round-trip for all cases")
    func immersionStyleRoundTrip() async throws {
        for style in CinemaImmersionStyle.allCases {
            let settings = CinemaSettings(immersionStyle: style, loadPersisted: false)
            #expect(settings.immersionStyle == style)
        }
    }

    // MARK: - Horizontal FOV

    @Test("horizontalFOV for default settings")
    func horizontalFOVDefault() async throws {
        let settings = CinemaSettings(screenWidth: 6.0, screenDistance: 4.0, loadPersisted: false)
        let expected = 2 * atan((6.0 / 2) / 4.0) * (180.0 / .pi)
        #expect(settings.horizontalFOV == expected)
    }

    @Test("horizontalFOV clamps distance to 0.1m")
    func horizontalFOVClampsDistance() async throws {
        let settings = CinemaSettings(screenWidth: 2.0, screenDistance: 0.0, loadPersisted: false)
        let expected = 2 * atan((2.0 / 2) / 0.1) * (180.0 / .pi)
        #expect(settings.horizontalFOV == expected)
    }

    @Test("horizontalFOV with very small distance")
    func horizontalFOVVerySmallDistance() async throws {
        let settings = CinemaSettings(screenWidth: 2.0, screenDistance: 0.05, loadPersisted: false)
        let expected = 2 * atan((2.0 / 2) / 0.1) * (180.0 / .pi)
        #expect(settings.horizontalFOV == expected)
    }

    @Test("horizontalFOV with zero screenWidth")
    func horizontalFOVZeroWidth() async throws {
        let settings = CinemaSettings(screenWidth: 0.0, screenDistance: 4.0, loadPersisted: false)
        #expect(settings.horizontalFOV == 0.0)
    }

    @Test("horizontalFOV with large width and small distance")
    func horizontalFOVLargeWidthSmallDistance() async throws {
        let settings = CinemaSettings(screenWidth: 20.0, screenDistance: 1.0, loadPersisted: false)
        let fov = settings.horizontalFOV
        #expect(fov > 120.0)
    }

    // MARK: - Comfort

    @Test("isComfortable false for default settings due to high FOV")
    func isComfortableDefault() async throws {
        let settings = CinemaSettings(loadPersisted: false)
        // Default: width=6.0, distance=4.0 → FOV ≈ 73.7° > 60°
        #expect(settings.isComfortable == false)
    }

    @Test("isComfortable false for high FOV")
    func isComfortableHighFOV() async throws {
        let settings = CinemaSettings(screenWidth: 20.0, screenDistance: 2.0, loadPersisted: false)
        #expect(settings.horizontalFOV > 60.0)
        #expect(settings.isComfortable == false)
    }

    @Test("isComfortable false for close distance with large width")
    func isComfortableCloseLargeWidth() async throws {
        let settings = CinemaSettings(screenWidth: 5.0, screenDistance: 1.0, loadPersisted: false)
        #expect(settings.screenDistance < 1.5)
        #expect(settings.screenWidth > 2.0)
        #expect(settings.isComfortable == false)
    }

    @Test("isComfortable true for close distance with very small width")
    func isComfortableCloseSmallWidth() async throws {
        // At distance=1.0, max width for FOV≤60 is 2*1.0*tan(30°) ≈ 1.155
        let maxWidth = 2 * 1.0 * tan(30.0 * .pi / 180.0)
        let settings = CinemaSettings(screenWidth: maxWidth * 0.95, screenDistance: 1.0, loadPersisted: false)
        #expect(settings.horizontalFOV < 60.0)
        #expect(settings.screenDistance < 1.5)
        #expect(settings.screenWidth <= 2.0)
        #expect(settings.isComfortable == true)
    }

    @Test("isComfortable true just below 60 degree FOV")
    func isComfortableAt60Degrees() async throws {
        // Solve for width where FOV == 60: width = 2 * distance * tan(30°)
        let distance = 4.0
        let width = 2 * distance * tan(30.0 * .pi / 180.0)
        // Use a slightly smaller width to stay comfortably under 60° and avoid FP issues
        let settings = CinemaSettings(screenWidth: width * 0.99, screenDistance: distance, loadPersisted: false)
        #expect(settings.horizontalFOV < 60.0)
        #expect(settings.isComfortable == true)
    }

    @Test("isComfortable true at 1.5m distance with small enough width")
    func isComfortableAtBoundary() async throws {
        // At distance=1.5, max width for FOV≤60 is 2*1.5*tan(30°) ≈ 1.732
        let maxWidth = 2 * 1.5 * tan(30.0 * .pi / 180.0)
        let settings = CinemaSettings(screenWidth: maxWidth * 0.99, screenDistance: 1.5, loadPersisted: false)
        #expect(settings.horizontalFOV < 60.0)
        #expect(settings.screenDistance >= 1.5)
        #expect(settings.isComfortable == true)
    }

    // MARK: - Apply Preset

    @Test("apply default preset")
    func applyDefaultPreset() async throws {
        let settings = CinemaSettings(loadPersisted: false)
        settings.apply(preset: .default)
        #expect(settings.screenWidth == 6.0)
        #expect(settings.screenDistance == 4.0)
        #expect(settings.screenHeight == 0.0)
        #expect(settings.screenTilt == 0.0)
        #expect(settings.seatOffset == .zero)
        #expect(settings.environmentDarkness == 0.8)
        #expect(settings.ambientLighting == 0.1)
        #expect(settings.immersionStyle == .full)
        #expect(settings.useSurroundingsEffect == true)
    }

    @Test("apply frontRow preset")
    func applyFrontRowPreset() async throws {
        let settings = CinemaSettings(loadPersisted: false)
        settings.apply(preset: .frontRow)
        #expect(settings.screenWidth == 5.0)
        #expect(settings.screenDistance == 2.5)
        #expect(settings.screenHeight == -0.3)
        #expect(settings.screenTilt == 5.0)
        #expect(settings.seatOffset == .zero)
        #expect(settings.environmentDarkness == 1.0)
        #expect(settings.ambientLighting == 0.05)
        #expect(settings.immersionStyle == .full)
        #expect(settings.useSurroundingsEffect == true)
    }

    @Test("apply backRow preset")
    func applyBackRowPreset() async throws {
        let settings = CinemaSettings(loadPersisted: false)
        settings.apply(preset: .backRow)
        #expect(settings.screenWidth == 4.5)
        #expect(settings.screenDistance == 8.0)
        #expect(settings.screenHeight == 0.5)
        #expect(settings.screenTilt == -3.0)
        #expect(settings.seatOffset == .zero)
        #expect(settings.environmentDarkness == 0.6)
        #expect(settings.ambientLighting == 0.2)
        #expect(settings.immersionStyle == .progressive)
        #expect(settings.useSurroundingsEffect == false)
    }

    @Test("apply imax preset")
    func applyImaxPreset() async throws {
        let settings = CinemaSettings(loadPersisted: false)
        settings.apply(preset: .imax)
        #expect(settings.screenWidth == 10.0)
        #expect(settings.screenDistance == 3.5)
        #expect(settings.screenHeight == 1.0)
        #expect(settings.screenTilt == 8.0)
        #expect(settings.seatOffset == SIMD3(0, 0.1, 0))
        #expect(settings.environmentDarkness == 1.0)
        #expect(settings.ambientLighting == 0.0)
        #expect(settings.immersionStyle == .full)
        #expect(settings.useSurroundingsEffect == true)
    }

    @Test("apply custom preset leaves values unchanged")
    func applyCustomPreset() async throws {
        let settings = CinemaSettings(loadPersisted: false)
        settings.screenWidth = 7.0
        settings.screenDistance = 5.0
        settings.apply(preset: .custom)
        #expect(settings.screenWidth == 7.0)
        #expect(settings.screenDistance == 5.0)
    }

    @Test("apply preset with explicit baseAspectRatio")
    func applyPresetWithBaseAspectRatio() async throws {
        let settings = CinemaSettings(videoAspectRatio: 16.0 / 9.0, loadPersisted: false)
        settings.apply(preset: .default, baseAspectRatio: 2.39)
        #expect(settings.videoAspectRatio == 2.39)
    }

    @Test("apply preset without baseAspectRatio preserves existing videoAspectRatio")
    func applyPresetWithoutBaseAspectRatio() async throws {
        let settings = CinemaSettings(videoAspectRatio: 2.0, loadPersisted: false)
        settings.apply(preset: .frontRow)
        #expect(settings.videoAspectRatio == 2.0)
    }

    // MARK: - Active Preset

    @Test("activePreset getter returns default for matching default settings")
    func activePresetDefault() async throws {
        let settings = CinemaSettings(preset: .default, baseAspectRatio: 16.0 / 9.0)
        #expect(settings.activePreset == .default)
    }

    @Test("activePreset getter returns frontRow for matching frontRow settings")
    func activePresetFrontRow() async throws {
        let settings = CinemaSettings(preset: .frontRow, baseAspectRatio: 16.0 / 9.0)
        #expect(settings.activePreset == .frontRow)
    }

    @Test("activePreset getter returns backRow for matching backRow settings")
    func activePresetBackRow() async throws {
        let settings = CinemaSettings(preset: .backRow, baseAspectRatio: 16.0 / 9.0)
        #expect(settings.activePreset == .backRow)
    }

    @Test("activePreset getter returns imax for matching imax settings")
    func activePresetImax() async throws {
        let settings = CinemaSettings(preset: .imax, baseAspectRatio: 16.0 / 9.0)
        #expect(settings.activePreset == .imax)
    }

    @Test("activePreset getter returns custom for modified settings")
    func activePresetCustom() async throws {
        let settings = CinemaSettings(preset: .default, baseAspectRatio: 16.0 / 9.0)
        settings.screenWidth = 99.0
        #expect(settings.activePreset == .custom)
    }

    @Test("activePreset getter returns custom when only immersion style differs")
    func activePresetCustomImmersionStyle() async throws {
        let settings = CinemaSettings(preset: .default, baseAspectRatio: 16.0 / 9.0)
        settings.immersionStyle = .mixed
        #expect(settings.activePreset == .custom)
    }

    @Test("activePreset getter returns custom when only environmentDarkness differs")
    func activePresetCustomDarkness() async throws {
        let settings = CinemaSettings(preset: .default, baseAspectRatio: 16.0 / 9.0)
        settings.environmentDarkness = 0.5
        #expect(settings.activePreset == .custom)
    }

    @Test("activePreset setter applies default preset")
    func activePresetSetterDefault() async throws {
        let settings = CinemaSettings(preset: .imax, baseAspectRatio: 16.0 / 9.0)
        settings.activePreset = .default
        #expect(settings.activePreset == .default)
        #expect(settings.screenWidth == 6.0)
    }

    @Test("activePreset setter applies frontRow preset")
    func activePresetSetterFrontRow() async throws {
        let settings = CinemaSettings(preset: .default, baseAspectRatio: 16.0 / 9.0)
        settings.activePreset = .frontRow
        #expect(settings.activePreset == .frontRow)
    }

    @Test("activePreset setter applies custom preset leaves values unchanged")
    func activePresetSetterCustom() async throws {
        let settings = CinemaSettings(preset: .default, baseAspectRatio: 16.0 / 9.0)
        settings.screenWidth = 7.5
        settings.activePreset = .custom
        #expect(settings.screenWidth == 7.5)
    }

    // MARK: - Persistence

    @Test("save writes values to UserDefaults")
    func saveToUserDefaults() async throws {
        clearCinemaDefaults()
        let settings = CinemaSettings(
            screenWidth: 7.0,
            screenDistance: 3.0,
            screenHeight: 0.5,
            screenTilt: 2.0,
            seatOffset: SIMD3(0.1, 0.2, 0.3),
            environmentDarkness: 0.5,
            ambientLighting: 0.3,
            immersionStyle: .mixed,
            useSurroundingsEffect: false,
            videoAspectRatio: 2.39,
            loadPersisted: false
        )
        settings.save()

        let defs = UserDefaults.standard
        #expect(defs.double(forKey: "CinemaEnvironment.screenWidth") == 7.0)
        #expect(defs.double(forKey: "CinemaEnvironment.screenDistance") == 3.0)
        #expect(defs.double(forKey: "CinemaEnvironment.screenHeight") == 0.5)
        #expect(defs.double(forKey: "CinemaEnvironment.screenTilt") == 2.0)
        #expect(defs.double(forKey: "CinemaEnvironment.seatOffsetX") == 0.1)
        #expect(defs.double(forKey: "CinemaEnvironment.seatOffsetY") == 0.2)
        #expect(defs.double(forKey: "CinemaEnvironment.seatOffsetZ") == 0.3)
        #expect(defs.double(forKey: "CinemaEnvironment.environmentDarkness") == 0.5)
        #expect(defs.double(forKey: "CinemaEnvironment.ambientLighting") == 0.3)
        #expect(defs.string(forKey: "CinemaEnvironment.immersionStyle") == CinemaImmersionStyle.mixed.rawValue)
        #expect(defs.bool(forKey: "CinemaEnvironment.useSurroundingsEffect") == false)
        #expect(defs.double(forKey: "CinemaEnvironment.videoAspectRatio") == 2.39)

        clearCinemaDefaults()
    }

    @Test("init with loadPersisted true restores all values from UserDefaults")
    func loadFromUserDefaults() async throws {
        clearCinemaDefaults()
        let defs = UserDefaults.standard
        defs.set(9.0, forKey: "CinemaEnvironment.screenWidth")
        defs.set(5.0, forKey: "CinemaEnvironment.screenDistance")
        defs.set(1.0, forKey: "CinemaEnvironment.screenHeight")
        defs.set(-2.0, forKey: "CinemaEnvironment.screenTilt")
        defs.set(0.5, forKey: "CinemaEnvironment.seatOffsetX")
        defs.set(0.6, forKey: "CinemaEnvironment.seatOffsetY")
        defs.set(0.7, forKey: "CinemaEnvironment.seatOffsetZ")
        defs.set(0.3, forKey: "CinemaEnvironment.environmentDarkness")
        defs.set(0.4, forKey: "CinemaEnvironment.ambientLighting")
        defs.set(CinemaImmersionStyle.progressive.rawValue, forKey: "CinemaEnvironment.immersionStyle")
        defs.set(true, forKey: "CinemaEnvironment.useSurroundingsEffect")
        defs.set(4.0 / 3.0, forKey: "CinemaEnvironment.videoAspectRatio")

        // Use loadPersisted: true so load() is called inside withPersistenceDisabled
        let settings = CinemaSettings(loadPersisted: true)

        #expect(settings.screenWidth == 9.0)
        #expect(settings.screenDistance == 5.0)
        #expect(settings.screenHeight == 1.0)
        #expect(settings.screenTilt == -2.0)
        #expect(settings.seatOffset == SIMD3(0.5, 0.6, 0.7))
        #expect(settings.environmentDarkness == 0.3)
        #expect(settings.ambientLighting == 0.4)
        #expect(settings.immersionStyle == .progressive)
        #expect(settings.useSurroundingsEffect == true)
        #expect(settings.videoAspectRatio == 4.0 / 3.0)

        clearCinemaDefaults()
    }

    // MARK: - Auto-Dim on Play

    @Test("autoDimOnPlay defaults to true")
    func autoDimOnPlayDefault() async throws {
        let settings = CinemaSettings(loadPersisted: false)
        #expect(settings.autoDimOnPlay == true)
    }

    @Test("autoDimOnPlay custom init value is honored")
    func autoDimOnPlayCustomInit() async throws {
        let settings = CinemaSettings(autoDimOnPlay: false, loadPersisted: false)
        #expect(settings.autoDimOnPlay == false)
    }

    @Test("autoDimOnPlay save/load round-trips through UserDefaults")
    func autoDimOnPlayRoundTrip() async throws {
        clearCinemaDefaults()
        defer { clearCinemaDefaults() }

        let settings = CinemaSettings(autoDimOnPlay: false, loadPersisted: false)
        settings.save()

        let defs = UserDefaults.standard
        #expect(defs.bool(forKey: SettingsKeys.cinemaAutoDimOnPlay) == false)

        let reloaded = CinemaSettings(loadPersisted: true)
        #expect(reloaded.autoDimOnPlay == false)
    }

    @Test("autoDimOnPlay load preserves default when UserDefaults has no value")
    func autoDimOnPlayLoadPreservesDefault() async throws {
        clearCinemaDefaults()
        defer { clearCinemaDefaults() }

        let settings = CinemaSettings(loadPersisted: false)
        settings.load()
        #expect(settings.autoDimOnPlay == true)
    }

    @Test("load preserves defaults when UserDefaults has no values")
    func loadPreservesDefaults() async throws {
        clearCinemaDefaults()
        let settings = CinemaSettings(loadPersisted: false)
        settings.load()
        #expect(settings.screenWidth == 6.0)
        #expect(settings.screenDistance == 4.0)
        #expect(settings.immersionStyle == .full)
    }

    @Test("load ignores partial UserDefaults values")
    func loadPartialUserDefaults() async throws {
        clearCinemaDefaults()
        let defs = UserDefaults.standard
        defs.set(12.0, forKey: "CinemaEnvironment.screenWidth")
        // Leave other keys absent

        let settings = CinemaSettings(loadPersisted: false)
        settings.load()

        #expect(settings.screenWidth == 12.0)
        #expect(settings.screenDistance == 4.0) // default
        #expect(settings.immersionStyle == .full) // default

        clearCinemaDefaults()
    }

    @Test("init with loadPersisted true loads from UserDefaults")
    func initWithLoadPersistedTrue() async throws {
        clearCinemaDefaults()
        let defs = UserDefaults.standard
        defs.set(15.0, forKey: "CinemaEnvironment.screenWidth")

        let settings = CinemaSettings(loadPersisted: true)
        #expect(settings.screenWidth == 15.0)

        clearCinemaDefaults()
    }

    @Test("init with loadPersisted false ignores UserDefaults")
    func initWithLoadPersistedFalse() async throws {
        clearCinemaDefaults()
        let defs = UserDefaults.standard
        defs.set(15.0, forKey: "CinemaEnvironment.screenWidth")

        let settings = CinemaSettings(loadPersisted: false)
        #expect(settings.screenWidth == 6.0)

        clearCinemaDefaults()
    }

    // MARK: - Edge Cases

    @Test("very large screenWidth and distance")
    func veryLargeValues() async throws {
        let settings = CinemaSettings(screenWidth: 1000.0, screenDistance: 1000.0, loadPersisted: false)
        #expect(settings.screenSize.width == 1000.0)
        #expect(settings.horizontalFOV > 0)
        #expect(settings.horizontalFOV < 180)
    }

    @Test("very small positive screenWidth")
    func verySmallWidth() async throws {
        let settings = CinemaSettings(screenWidth: 0.001, screenDistance: 4.0, loadPersisted: false)
        #expect(settings.horizontalFOV > 0)
        #expect(settings.horizontalFOV < 1)
        #expect(settings.isComfortable == true)
    }

    @Test("negative screenWidth produces negative FOV")
    func negativeScreenWidth() async throws {
        let settings = CinemaSettings(screenWidth: -5.0, screenDistance: 4.0, loadPersisted: false)
        #expect(settings.horizontalFOV < 0)
    }

    @Test("zero distance clamps to 0.1 for FOV")
    func zeroDistanceFOV() async throws {
        let settings = CinemaSettings(screenWidth: 2.0, screenDistance: 0.0, loadPersisted: false)
        let fov = settings.horizontalFOV
        let expected = 2 * atan((2.0 / 2) / 0.1) * (180.0 / .pi)
        #expect(fov == expected)
    }

    @Test("CinemaPreset title values")
    func cinemaPresetTitles() async throws {
        #expect(CinemaPreset.default.title == "Default")
        #expect(CinemaPreset.frontRow.title == "Front Row")
        #expect(CinemaPreset.backRow.title == "Back Row")
        #expect(CinemaPreset.imax.title == "IMAX")
        #expect(CinemaPreset.custom.title == "Custom")
    }

    @Test("CinemaPreset id values")
    func cinemaPresetIDs() async throws {
        #expect(CinemaPreset.default.id == "default")
        #expect(CinemaPreset.frontRow.id == "frontRow")
        #expect(CinemaPreset.backRow.id == "backRow")
        #expect(CinemaPreset.imax.id == "imax")
        #expect(CinemaPreset.custom.id == "custom")
    }

    @Test("CinemaPreset allCases count")
    func cinemaPresetAllCases() async throws {
        #expect(CinemaPreset.allCases.count == 5)
    }

    @Test("CinemaImmersionStyle allCases count")
    func cinemaImmersionStyleAllCases() async throws {
        #expect(CinemaImmersionStyle.allCases.count == 3)
    }
}
#endif
