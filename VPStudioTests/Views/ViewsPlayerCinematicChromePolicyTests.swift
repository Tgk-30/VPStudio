import Testing
import CoreGraphics
@testable import VPStudio

@Suite("PlayerCinematicChromePolicy Constants")
struct PlayerCinematicChromePolicyTestsViewsViewsplayercinematicchromepolicytests {
    @Test("Transport card corner radius")
    func transportCardCornerRadius() {
        #expect(PlayerCinematicChromePolicy.transportCardCornerRadius == 26)
    }

    @Test("Top scrim height")
    func topScrimHeight() {
        #expect(PlayerCinematicChromePolicy.topScrimHeight == 96)
    }

    @Test("Bottom scrim height")
    func bottomScrimHeight() {
        #expect(PlayerCinematicChromePolicy.bottomScrimHeight == 132)
    }

    @Test("Quick actions corner radius")
    func quickActionsCornerRadius() {
        #expect(PlayerCinematicChromePolicy.quickActionsCornerRadius == 20)
    }

    @Test("Top bar button size")
    func topBarButtonSize() {
        #expect(PlayerCinematicChromePolicy.topBarButtonSize == 50)
    }

    @Test("Primary transport button size")
    func primaryTransportButtonSize() {
        #expect(PlayerCinematicChromePolicy.primaryTransportButtonSize == 72)
    }

    @Test("Secondary transport button size")
    func secondaryTransportButtonSize() {
        #expect(PlayerCinematicChromePolicy.secondaryTransportButtonSize == VPSpace.minTapTarget)
    }

    @Test("Controls dock max width")
    func controlsDockMaxWidth() {
        #expect(PlayerCinematicChromePolicy.controlsDockMaxWidth == 860)
    }

    @Test("Quick actions max width")
    func quickActionsMaxWidth() {
        #expect(PlayerCinematicChromePolicy.quickActionsMaxWidth == 640)
    }

    @Test("Transport card max width")
    func transportCardMaxWidth() {
        #expect(PlayerCinematicChromePolicy.transportCardMaxWidth == 780)
    }

    @Test("Controls dock spacing")
    func controlsDockSpacing() {
        #expect(PlayerCinematicChromePolicy.controlsDockSpacing == 8)
    }

    @Test("Controls dock horizontal padding")
    func controlsDockHorizontalPadding() {
        #expect(PlayerCinematicChromePolicy.controlsDockHorizontalPadding == 18)
    }

    @Test("Controls dock bottom padding")
    func controlsDockBottomPadding() {
        #expect(PlayerCinematicChromePolicy.controlsDockBottomPadding == 18)
    }

    @Test("Transport card horizontal padding")
    func transportCardHorizontalPadding() {
        #expect(PlayerCinematicChromePolicy.transportCardHorizontalPadding == 20)
    }

    @Test("Transport card vertical padding")
    func transportCardVerticalPadding() {
        #expect(PlayerCinematicChromePolicy.transportCardVerticalPadding == 12)
    }

    @Test("Transport internal spacing")
    func transportInternalSpacing() {
        #expect(PlayerCinematicChromePolicy.transportInternalSpacing == 10)
    }

    @Test("Skip back interval")
    func skipBackInterval() {
        #expect(PlayerCinematicChromePolicy.skipBackInterval == 10)
    }

    @Test("Skip forward interval")
    func skipForwardInterval() {
        #expect(PlayerCinematicChromePolicy.skipForwardInterval == 10)
    }

    @Test("Progress bar idle height")
    func progressBarIdleHeight() {
        #expect(PlayerCinematicChromePolicy.progressBarIdleHeight == 4)
    }

    @Test("Progress bar scrubbing height")
    func progressBarScrubbingHeight() {
        #expect(PlayerCinematicChromePolicy.progressBarScrubbingHeight == 8)
    }

    @Test("Window corner radius")
    func windowCornerRadius() {
        #expect(PlayerCinematicChromePolicy.windowCornerRadius == 28)
    }

    @Test("All size constants are positive")
    func positiveConstants() {
        #expect(PlayerCinematicChromePolicy.topBarButtonSize > 0)
        #expect(PlayerCinematicChromePolicy.primaryTransportButtonSize > 0)
        #expect(PlayerCinematicChromePolicy.secondaryTransportButtonSize > 0)
        #expect(PlayerCinematicChromePolicy.controlsDockMaxWidth > 0)
        #expect(PlayerCinematicChromePolicy.quickActionsMaxWidth > 0)
        #expect(PlayerCinematicChromePolicy.transportCardMaxWidth > 0)
    }

    @Test("Progress bar scrubbing height is greater than idle height")
    func progressBarHeightProgression() {
        #expect(PlayerCinematicChromePolicy.progressBarScrubbingHeight > PlayerCinematicChromePolicy.progressBarIdleHeight)
    }

    @Test("Primary button is larger than secondary")
    func buttonSizeProgression() {
        #expect(PlayerCinematicChromePolicy.primaryTransportButtonSize > PlayerCinematicChromePolicy.secondaryTransportButtonSize)
    }
}
