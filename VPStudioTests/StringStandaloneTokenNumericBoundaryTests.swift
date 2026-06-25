import Testing
import Foundation
@testable import VPStudio

@Suite("String.containsStandaloneToken numeric boundaries")
struct StringStandaloneTokenNumericBoundaryTests {

    @Test func multiDigitTokensDoNotMatchInsideLargerNumbers() {
        #expect("Movie.1800.VR".containsStandaloneToken("180") == false)
        #expect("Movie.2180.VR".containsStandaloneToken("180") == false)
    }

    @Test func singleDigitTokensFollowCurrentAdjacencySemantics() {
        #expect("Movie.2.VR".containsStandaloneToken("2") == true)
        #expect("Movie.12.VR".containsStandaloneToken("2") == false)
        #expect("Movie.21.VR".containsStandaloneToken("2") == false)
        #expect("Movie.2p.VR".containsStandaloneToken("2") == false)
        #expect("Movie.p2.VR".containsStandaloneToken("2") == false)
    }

    @Test func numericTokensDoNotMatchResolutionOrFrameRateSuffixes() {
        #expect("Movie.1080p.BluRay".containsStandaloneToken("1080") == false)
        #expect("Movie.2160p.HDR".containsStandaloneToken("2160") == false)
        #expect("Movie.p30.Source".containsStandaloneToken("30") == false)
        #expect("Movie.p60.Source".containsStandaloneToken("60") == false)
        #expect("Movie.p30.Source".containsStandaloneToken("p30") == true)
    }

    @Test func nonNumericTokensStillAllowBoundedNumericAffixes() {
        #expect("Movie.SBS2.1080p".containsStandaloneToken("sbs") == true)
        #expect("Movie.2SBS.1080p".containsStandaloneToken("sbs") == true)
    }
}
