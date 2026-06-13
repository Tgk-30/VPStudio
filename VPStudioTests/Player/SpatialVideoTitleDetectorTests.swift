import Testing
import Foundation
@testable import VPStudio

@Suite("SpatialVideoTitleDetector")
struct SpatialVideoTitleDetectorTests {

    // MARK: - Mono (no spatial indicators)

    @Test func plainTitleReturnsMono() {
        #expect(SpatialVideoTitleDetector.stereoMode(fromTitle: "Movie.2024.1080p.mp4") == .mono)
    }

    @Test func emptyTitleReturnsMono() {
        #expect(SpatialVideoTitleDetector.stereoMode(fromTitle: "") == .mono)
    }

    // MARK: - Side-by-Side

    @Test func sbsReturnsSideBySide() {
        #expect(SpatialVideoTitleDetector.stereoMode(fromTitle: "Movie.SBS.3D.mp4") == .sideBySide)
    }

    @Test func sideBySideReturnsSideBySide() {
        #expect(SpatialVideoTitleDetector.stereoMode(fromTitle: "Movie.Side.By.Side.3D.mp4") == .sideBySide)
    }

    @Test func sideDashByDashSideReturnsSideBySide() {
        #expect(SpatialVideoTitleDetector.stereoMode(fromTitle: "Movie.Side-By-Side.mp4") == .sideBySide)
    }

    @Test func sidebysideReturnsSideBySide() {
        #expect(SpatialVideoTitleDetector.stereoMode(fromTitle: "Movie.sidebyside.mp4") == .sideBySide)
    }

    @Test func halfSbsReturnsSideBySide() {
        #expect(SpatialVideoTitleDetector.stereoMode(fromTitle: "Movie.Half-SBS.mp4") == .sideBySide)
    }

    @Test func hsbsStandaloneTokenReturnsSideBySide() {
        #expect(SpatialVideoTitleDetector.stereoMode(fromTitle: "Movie.hsbs.1080p.mp4") == .sideBySide)
    }

    @Test func hsbsInsideWordDoesNotMatch() {
        // "hsb" should not match because it does not contain the substring "sbs"
        #expect(SpatialVideoTitleDetector.stereoMode(fromTitle: "Movie.hsb.file.mp4") == .mono)
    }

    // MARK: - Over-Under

    @Test func ouReturnsOverUnder() {
        #expect(SpatialVideoTitleDetector.stereoMode(fromTitle: "Movie.OU.3D.mp4") == .overUnder)
    }

    @Test func houReturnsOverUnder() {
        #expect(SpatialVideoTitleDetector.stereoMode(fromTitle: "Movie.HOU.3D.mp4") == .overUnder)
    }

    @Test func tabReturnsOverUnder() {
        #expect(SpatialVideoTitleDetector.stereoMode(fromTitle: "Movie.TAB.3D.mp4") == .overUnder)
    }

    @Test func overUnderReturnsOverUnder() {
        #expect(SpatialVideoTitleDetector.stereoMode(fromTitle: "Movie.Over.Under.mp4") == .overUnder)
    }

    @Test func overDashUnderReturnsOverUnder() {
        #expect(SpatialVideoTitleDetector.stereoMode(fromTitle: "Movie.Over-Under.mp4") == .overUnder)
    }

    @Test func ouInsideWordDoesNotMatch() {
        #expect(SpatialVideoTitleDetector.stereoMode(fromTitle: "Movie.soup.mp4") == .mono)
    }

    // MARK: - MV-HEVC

    @Test func mvHevcInTitleReturnsMvHevc() {
        #expect(SpatialVideoTitleDetector.stereoMode(fromTitle: "Movie.MV-HEVC.mp4") == .mvHevc)
    }

    @Test func spatialInTitleReturnsMvHevc() {
        #expect(SpatialVideoTitleDetector.stereoMode(fromTitle: "Movie.Spatial.Video.mp4") == .mvHevc)
    }

    @Test func codecHintMvHevcTakesPriority() {
        // Even if title has SBS, codec hint wins
        #expect(SpatialVideoTitleDetector.stereoMode(fromTitle: "Movie.SBS.mp4", codecHint: "mv-hevc") == .mvHevc)
    }

    @Test func codecHintWithUnderscoreMvHevc() {
        #expect(SpatialVideoTitleDetector.stereoMode(fromTitle: "Movie.mp4", codecHint: "mv_hevc") == .mvHevc)
    }

    @Test func codecHintMvHevcCompacted() {
        #expect(SpatialVideoTitleDetector.stereoMode(fromTitle: "Movie.mp4", codecHint: "mvhevc") == .mvHevc)
    }

    @Test func codecHintWithoutBothMvAndHevcDoesNotOverrideTitle() {
        #expect(SpatialVideoTitleDetector.stereoMode(fromTitle: "Movie.mp4", codecHint: "hevc") == .mono)
        #expect(SpatialVideoTitleDetector.stereoMode(fromTitle: "Movie.mp4", codecHint: "mv-avc") == .mono)
    }

    // MARK: - 180° VR

    @Test func standalone180WithVrReturnsSphere180() {
        #expect(SpatialVideoTitleDetector.stereoMode(fromTitle: "Movie.180.VR.mp4") == .sphere180)
    }

    @Test func standalone180With3dReturnsSphere180() {
        #expect(SpatialVideoTitleDetector.stereoMode(fromTitle: "Movie.180.3D.mp4") == .sphere180)
    }

    @Test func oneHundredEightyDegreesDoesNotMatch() {
        // "180" must be standalone token
        #expect(SpatialVideoTitleDetector.stereoMode(fromTitle: "Movie.180p.mp4") == .mono)
    }

    @Test func oneHundredEightyInsideLargerNumberDoesNotMatch() {
        #expect(SpatialVideoTitleDetector.stereoMode(fromTitle: "Movie.1800.VR.mp4") == .mono)
        #expect(SpatialVideoTitleDetector.stereoMode(fromTitle: "Movie.2180.VR.mp4") == .mono)
    }

    // MARK: - 360° VR

    @Test func threeSixtyVrReturnsSphere360() {
        #expect(SpatialVideoTitleDetector.stereoMode(fromTitle: "Movie.360VR.mp4") == .sphere360)
    }

    @Test func threeSixtyVideoReturnsSphere360() {
        #expect(SpatialVideoTitleDetector.stereoMode(fromTitle: "Movie.360 Video.mp4") == .sphere360)
    }

    @Test func threeSixtyDashVideoReturnsSphere360() {
        #expect(SpatialVideoTitleDetector.stereoMode(fromTitle: "Movie.360-Video.mp4") == .sphere360)
    }

    @Test func threeSixtyDegreeSymbolReturnsSphere360() {
        #expect(SpatialVideoTitleDetector.stereoMode(fromTitle: "Movie.360°.mp4") == .sphere360)
    }

    @Test func standalone360WithVrReturnsSphere360() {
        #expect(SpatialVideoTitleDetector.stereoMode(fromTitle: "Movie.360.vr.mp4") == .sphere360)
    }

    @Test func standalone360WithoutVrStillReturnsSphere360() {
        #expect(SpatialVideoTitleDetector.stereoMode(fromTitle: "Movie.360.mp4") == .sphere360)
    }

    @Test func threeSixtyPDoesNotMatch() {
        #expect(SpatialVideoTitleDetector.stereoMode(fromTitle: "Movie.360p.mp4") == .mono)
    }

    @Test func threeSixtyInsideWordDoesNotMatch() {
        #expect(SpatialVideoTitleDetector.stereoMode(fromTitle: "Movie.360video.mp4") == .mono)
    }
}
