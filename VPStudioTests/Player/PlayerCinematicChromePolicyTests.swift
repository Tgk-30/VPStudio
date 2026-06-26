import Foundation
import Testing
@testable import VPStudio

@Suite("PlayerCinematicChromePolicy - Timing Constants")
struct PlayerCinematicChromePolicyTimingTests {

    @Test
    func transportCardCornerRadius() {
        #expect(PlayerCinematicChromePolicy.transportCardCornerRadius == 26)
    }

    @Test
    func topScrimHeight() {
        #expect(PlayerCinematicChromePolicy.topScrimHeight == 96)
    }

    @Test
    func bottomScrimHeight() {
        #expect(PlayerCinematicChromePolicy.bottomScrimHeight == 132)
    }

    @Test
    func quickActionsCornerRadius() {
        #expect(PlayerCinematicChromePolicy.quickActionsCornerRadius == 20)
    }
}

@Suite("PlayerCinematicChromePolicy - Button Sizes")
struct PlayerCinematicChromePolicyButtonSizesTests {

    @Test
    func topBarButtonSize() {
        #expect(PlayerCinematicChromePolicy.topBarButtonSize == 50)
    }

    @Test
    func primaryTransportButtonSize() {
        #expect(PlayerCinematicChromePolicy.primaryTransportButtonSize == 72)
    }

    @Test
    func secondaryTransportButtonSize() {
        #expect(PlayerCinematicChromePolicy.secondaryTransportButtonSize == VPSpace.minTapTarget)
    }
}

@Suite("PlayerCinematicChromePolicy - Layout Constants")
struct PlayerCinematicChromePolicyLayoutTests {

    @Test
    func controlsDockMaxWidth() {
        #expect(PlayerCinematicChromePolicy.controlsDockMaxWidth == 860)
    }

    @Test
    func quickActionsMaxWidth() {
        #expect(PlayerCinematicChromePolicy.quickActionsMaxWidth == 640)
    }

    @Test
    func transportCardMaxWidth() {
        #expect(PlayerCinematicChromePolicy.transportCardMaxWidth == 780)
    }

    @Test
    func controlsDockSpacing() {
        #expect(PlayerCinematicChromePolicy.controlsDockSpacing == 8)
    }

    @Test
    func controlsDockHorizontalPadding() {
        #expect(PlayerCinematicChromePolicy.controlsDockHorizontalPadding == 18)
    }

    @Test
    func controlsDockBottomPadding() {
        #expect(PlayerCinematicChromePolicy.controlsDockBottomPadding == 56)
    }

    @Test
    func transportCardHorizontalPadding() {
        #expect(PlayerCinematicChromePolicy.transportCardHorizontalPadding == 20)
    }

    @Test
    func transportCardVerticalPadding() {
        #expect(PlayerCinematicChromePolicy.transportCardVerticalPadding == 12)
    }

    @Test
    func overlayClearanceIsDerivedFromTransportDockDimensions() {
        let expectedDockHeight = PlayerCinematicChromePolicy.controlsDockBottomPadding
            + (PlayerCinematicChromePolicy.transportCardVerticalPadding * 2)
            + PlayerCinematicChromePolicy.quickActionsEstimatedHeight
            + PlayerCinematicChromePolicy.progressHitHeight
            + PlayerCinematicChromePolicy.timeLabelsMinHeight
            + PlayerCinematicChromePolicy.primaryTransportButtonSize
            + (PlayerCinematicChromePolicy.transportInternalSpacing * 3)

        #expect(PlayerCinematicChromePolicy.estimatedTransportDockHeight == expectedDockHeight)
        #expect(
            PlayerCinematicChromePolicy.overlayBottomPaddingAboveTransportDock
                == expectedDockHeight + PlayerCinematicChromePolicy.overlayDockClearance
        )
    }

    @Test
    func transportInternalSpacing() {
        #expect(PlayerCinematicChromePolicy.transportInternalSpacing == 10)
    }
}

@Suite("PlayerCinematicChromePolicy - Skip Intervals")
struct PlayerCinematicChromePolicySkipIntervalsTests {

    @Test
    func skipBackInterval() {
        #expect(PlayerCinematicChromePolicy.skipBackInterval == 10)
    }

    @Test
    func skipForwardInterval() {
        #expect(PlayerCinematicChromePolicy.skipForwardInterval == 10)
    }
}

@Suite("PlayerCinematicChromePolicy - Progress Bar")
struct PlayerCinematicChromePolicyProgressBarTests {

    @Test
    func progressBarIdleHeight() {
        #expect(PlayerCinematicChromePolicy.progressBarIdleHeight == 4)
    }

    @Test
    func progressBarScrubbingHeight() {
        #expect(PlayerCinematicChromePolicy.progressBarScrubbingHeight == 8)
    }
}

@Suite("PlayerCinematicChromePolicy - Window")
struct PlayerCinematicChromePolicyWindowTests {

    @Test
    func windowCornerRadius() {
        #expect(PlayerCinematicChromePolicy.windowCornerRadius == 28)
    }
}
