import Foundation
import Testing
@testable import VPStudio

#if os(visionOS)
@Suite("CinemaImmersionStyle - Enum Cases")
struct CinemaImmersionStyleTests {

    @Test
    func allCasesExist() {
        #expect(CinemaImmersionStyle.allCases.count == 3)
    }

    @Test
    func mixedCaseExists() {
        #expect(CinemaImmersionStyle.mixed.rawValue == "mixed")
    }

    @Test
    func fullCaseExists() {
        #expect(CinemaImmersionStyle.full.rawValue == "full")
    }

    @Test
    func progressiveCaseExists() {
        #expect(CinemaImmersionStyle.progressive.rawValue == "progressive")
    }

    @Test
    func rawValuesAreDistinct() {
        #expect(CinemaImmersionStyle.mixed.rawValue != CinemaImmersionStyle.full.rawValue)
        #expect(CinemaImmersionStyle.mixed.rawValue != CinemaImmersionStyle.progressive.rawValue)
        #expect(CinemaImmersionStyle.full.rawValue != CinemaImmersionStyle.progressive.rawValue)
    }
}

@Suite("CinemaPreset - Enum Cases")
struct CinemaPresetTests {

    @Test
    func allPresetsExist() {
        #expect(CinemaPreset.allCases.count == 5)
    }

    @Test
    func defaultPresetTitle() {
        #expect(CinemaPreset.default.title == "Default")
    }

    @Test
    func frontRowPresetTitle() {
        #expect(CinemaPreset.frontRow.title == "Front Row")
    }

    @Test
    func backRowPresetTitle() {
        #expect(CinemaPreset.backRow.title == "Back Row")
    }

    @Test
    func imaxPresetTitle() {
        #expect(CinemaPreset.imax.title == "IMAX")
    }

    @Test
    func customPresetTitle() {
        #expect(CinemaPreset.custom.title == "Custom")
    }

    @Test
    func idMatchesRawValue() {
        #expect(CinemaPreset.default.id == "default")
        #expect(CinemaPreset.frontRow.id == "frontRow")
        #expect(CinemaPreset.backRow.id == "backRow")
        #expect(CinemaPreset.imax.id == "imax")
        #expect(CinemaPreset.custom.id == "custom")
    }
}
#endif
