import SwiftUI
import Testing
@testable import VPStudio

#if os(visionOS)
@Suite("ScreenSizePreset Extension")
struct ScreenSizePresetExtensionTests {

    @Test("subtitleFontSize for personal preset")
    func subtitleFontSizePersonal() {
        #expect(ScreenSizePreset.personal.subtitleFontSize == 36)
    }

    @Test("subtitleFontSize for cinema preset")
    func subtitleFontSizeCinema() {
        #expect(ScreenSizePreset.cinema.subtitleFontSize == 60)
    }

    @Test("subtitleFontSize for imax preset")
    func subtitleFontSizeIMAX() {
        #expect(ScreenSizePreset.imax.subtitleFontSize == 80)
    }

    @Test("subtitleMaxWidth for personal preset")
    func subtitleMaxWidthPersonal() {
        #expect(ScreenSizePreset.personal.subtitleMaxWidth == 1200)
    }

    @Test("subtitleMaxWidth for cinema preset")
    func subtitleMaxWidthCinema() {
        #expect(ScreenSizePreset.cinema.subtitleMaxWidth == 2000)
    }

    @Test("subtitleMaxWidth for imax preset")
    func subtitleMaxWidthIMAX() {
        #expect(ScreenSizePreset.imax.subtitleMaxWidth == 3200)
    }

    @Test("subtitleVerticalOffset calculation for personal preset")
    func subtitleVerticalOffsetPersonal() {
        let preset = ScreenSizePreset.personal
        let expectedOffset = preset.height / 2 + 0.15
        #expect(preset.subtitleVerticalOffset == expectedOffset)
    }

    @Test("subtitleVerticalOffset calculation for cinema preset")
    func subtitleVerticalOffsetCinema() {
        let preset = ScreenSizePreset.cinema
        let expectedOffset = preset.height / 2 + 0.15
        #expect(preset.subtitleVerticalOffset == expectedOffset)
    }

    @Test("subtitleVerticalOffset calculation for imax preset")
    func subtitleVerticalOffsetIMAX() {
        let preset = ScreenSizePreset.imax
        let expectedOffset = preset.height / 2 + 0.15
        #expect(preset.subtitleVerticalOffset == expectedOffset)
    }

    @Test("subtitle vertical offset is height/2 + 0.15m gap")
    func subtitleVerticalOffsetFormula() {
        for preset in ScreenSizePreset.allCases {
            let expected = preset.height / 2 + 0.15
            #expect(preset.subtitleVerticalOffset == expected)
        }
    }
}

@Suite("ScreenSizePreset Properties")
struct ScreenSizePresetPropertiesTests {

    @Test("personal preset dimensions")
    func personalDimensions() {
        #expect(ScreenSizePreset.personal.width == 6)
        #expect(ScreenSizePreset.personal.height == 3.375)
        #expect(ScreenSizePreset.personal.distance == 10)
    }

    @Test("cinema preset dimensions")
    func cinemaDimensions() {
        #expect(ScreenSizePreset.cinema.width == 10)
        #expect(ScreenSizePreset.cinema.height == 5.625)
        #expect(ScreenSizePreset.cinema.distance == 20)
    }

    @Test("imax preset dimensions")
    func imaxDimensions() {
        #expect(ScreenSizePreset.imax.width == 16)
        #expect(ScreenSizePreset.imax.height == 9)
        #expect(ScreenSizePreset.imax.distance == 35)
    }

    @Test("next cycles through all presets")
    func nextCycles() {
        #expect(ScreenSizePreset.personal.next == .cinema)
        #expect(ScreenSizePreset.cinema.next == .imax)
        #expect(ScreenSizePreset.imax.next == .personal)
    }

    @Test("allCases contains all presets")
    func allCasesCount() {
        #expect(ScreenSizePreset.allCases.count == 3)
    }
}
#endif
