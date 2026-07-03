import Foundation
import Testing
@testable import VPStudio

@Suite("PlayerCinematicChromePolicy - Timing Constants")
struct PlayerCinematicChromePolicyTimingTests {

    @Test
    func transportCardCornerRadius() {
        #expect(PlayerCinematicChromePolicy.transportCardCornerRadius == 22)
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
        #expect(PlayerCinematicChromePolicy.topBarButtonSize == VPSpace.minTapTarget)
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
        #expect(PlayerCinematicChromePolicy.controlsDockMaxWidth == 960)
    }

    @Test
    func quickActionsMaxWidth() {
        #expect(PlayerCinematicChromePolicy.quickActionsMaxWidth == 700)
    }

    @Test
    func infoPillScrollCueFadesTrailingOverflow() {
        #expect(PlayerInfoPillScrollCuePolicy.trailingFadeStart == 0.93)
        #expect(PlayerInfoPillScrollCuePolicy.trailingFadeStart < PlayerInfoPillScrollCuePolicy.trailingFadeEnd)
        #expect(PlayerInfoPillScrollCuePolicy.trailingFadeEnd == 1.0)
    }

    @Test
    func transportCardMaxWidth() {
        #expect(PlayerCinematicChromePolicy.transportCardMinWidth == 660)
        #expect(PlayerCinematicChromePolicy.transportCardMaxWidth == 840)
        #expect(PlayerCinematicChromePolicy.transportCardMinWidth < PlayerCinematicChromePolicy.transportCardMaxWidth)
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
    func appleEnvironmentDockChromeSitsCloserToSystemWindowEdge() {
        #expect(PlayerCinematicChromePolicy.appleEnvironmentControlsDockBottomPadding == 14)
        #expect(PlayerCinematicChromePolicy.appleEnvironmentControlsDockBottomPadding < PlayerCinematicChromePolicy.controlsDockBottomPadding)
        #expect(PlayerCinematicChromePolicy.resolvedControlsDockBottomPadding(usesAppleEnvironmentMode: true) == 14)
        #expect(PlayerCinematicChromePolicy.resolvedControlsDockBottomPadding(usesAppleEnvironmentMode: false) == 56)
    }

    @Test
    func appleEnvironmentExpansionUsesLargeFreeformWindowEnvelope() {
        #expect(PlayerCinematicChromePolicy.appleEnvironmentWindowMinimumSize.width == 640)
        #expect(PlayerCinematicChromePolicy.appleEnvironmentWindowMinimumSize.height == 360)
        #expect(PlayerCinematicChromePolicy.appleEnvironmentWindowMaximumSize.width == 3840)
        #expect(PlayerCinematicChromePolicy.appleEnvironmentWindowMaximumSize.height == 3840)
        #expect(PlayerCinematicChromePolicy.appleEnvironmentExpandedWindowSize.width == 2400)
        #expect(PlayerCinematicChromePolicy.appleEnvironmentExpandedWindowSize.height == 1350)
        #expect(PlayerCinematicChromePolicy.appleEnvironmentExpandedWindowSize.width > PlayerCinematicChromePolicy.appleEnvironmentWindowMinimumSize.width)
        #expect(PlayerCinematicChromePolicy.appleEnvironmentExpandedWindowSize.height > PlayerCinematicChromePolicy.appleEnvironmentWindowMinimumSize.height)
        #expect(PlayerCinematicChromePolicy.appleEnvironmentExpandedWindowSize.width <= PlayerCinematicChromePolicy.appleEnvironmentWindowMaximumSize.width)
        #expect(PlayerCinematicChromePolicy.appleEnvironmentExpandedWindowSize.height <= PlayerCinematicChromePolicy.appleEnvironmentWindowMaximumSize.height)
    }

    @Test
    func transportCardHorizontalPadding() {
        #expect(PlayerCinematicChromePolicy.transportCardHorizontalPadding == 24)
    }

    @Test
    func transportCardVerticalPadding() {
        #expect(PlayerCinematicChromePolicy.transportCardVerticalPadding == 12)
    }

    @Test
    func transportObsidianScrimOpacityStaysSubordinateToVideoContent() {
        #expect(PlayerCinematicChromePolicy.transportObsidianScrimOpacity == 0.18)
        #expect(PlayerCinematicChromePolicy.topBarButtonObsidianScrimOpacity == 0.26)
    }

    @Test
    func appleEnvironmentTransportChromeIsNarrowerAndLighter() {
        #expect(PlayerCinematicChromePolicy.appleEnvironmentTransportCardMinWidth == 540)
        #expect(PlayerCinematicChromePolicy.appleEnvironmentTransportCardMaxWidth == 660)
        #expect(PlayerCinematicChromePolicy.appleEnvironmentTransportCardMinWidth < PlayerCinematicChromePolicy.appleEnvironmentTransportCardMaxWidth)
        #expect(PlayerCinematicChromePolicy.appleEnvironmentTransportCardMaxWidth < PlayerCinematicChromePolicy.transportCardMaxWidth)
        #expect(PlayerCinematicChromePolicy.resolvedTransportCardMinWidth(usesAppleEnvironmentMode: true) == 540)
        #expect(PlayerCinematicChromePolicy.resolvedTransportCardMaxWidth(usesAppleEnvironmentMode: true) == 660)
        #expect(PlayerCinematicChromePolicy.resolvedTransportCardMinWidth(usesAppleEnvironmentMode: false) == 660)
        #expect(PlayerCinematicChromePolicy.resolvedTransportCardMaxWidth(usesAppleEnvironmentMode: false) == 840)

        #expect(PlayerCinematicChromePolicy.appleEnvironmentTransportCardVerticalPadding == 6)
        #expect(PlayerCinematicChromePolicy.appleEnvironmentTransportInternalSpacing == 7)
        #expect(PlayerCinematicChromePolicy.appleEnvironmentTransportControlSpacing == 18)
        #expect(PlayerCinematicChromePolicy.appleEnvironmentTransportCardVerticalPadding < PlayerCinematicChromePolicy.transportCardVerticalPadding)
        #expect(PlayerCinematicChromePolicy.appleEnvironmentTransportInternalSpacing < PlayerCinematicChromePolicy.transportInternalSpacing)
        #expect(PlayerCinematicChromePolicy.appleEnvironmentTransportControlSpacing < PlayerCinematicChromePolicy.transportControlSpacing)
        #expect(PlayerCinematicChromePolicy.resolvedTransportCardVerticalPadding(usesAppleEnvironmentMode: true) == 6)
        #expect(PlayerCinematicChromePolicy.resolvedTransportCardVerticalPadding(usesAppleEnvironmentMode: false) == 12)
        #expect(PlayerCinematicChromePolicy.resolvedTransportInternalSpacing(usesAppleEnvironmentMode: true) == 7)
        #expect(PlayerCinematicChromePolicy.resolvedTransportInternalSpacing(usesAppleEnvironmentMode: false) == 12)
        #expect(PlayerCinematicChromePolicy.resolvedTransportControlSpacing(usesAppleEnvironmentMode: true) == 18)
        #expect(PlayerCinematicChromePolicy.resolvedTransportControlSpacing(usesAppleEnvironmentMode: false) == 28)

        #expect(PlayerCinematicChromePolicy.appleEnvironmentTransportGlassTintOpacity == 0.035)
        #expect(PlayerCinematicChromePolicy.appleEnvironmentTransportGlassTintOpacity < 0.08)
        #expect(PlayerCinematicChromePolicy.resolvedTransportGlassTintOpacity(usesAppleEnvironmentMode: true) == 0.035)
        #expect(PlayerCinematicChromePolicy.resolvedTransportGlassTintOpacity(usesAppleEnvironmentMode: false) == 0.11)
        #expect(PlayerCinematicChromePolicy.appleEnvironmentTransportObsidianScrimOpacity == 0.12)
        #expect(PlayerCinematicChromePolicy.appleEnvironmentTransportObsidianScrimOpacity < PlayerCinematicChromePolicy.transportObsidianScrimOpacity)
        #expect(PlayerCinematicChromePolicy.resolvedTransportObsidianScrimOpacity(usesAppleEnvironmentMode: true) == 0.12)
        #expect(PlayerCinematicChromePolicy.resolvedTransportObsidianScrimOpacity(usesAppleEnvironmentMode: false) == 0.18)
        #expect(PlayerCinematicChromePolicy.resolvedTransportUsesLightweightMaterial(usesAppleEnvironmentMode: true))
        #expect(!PlayerCinematicChromePolicy.resolvedTransportUsesLightweightMaterial(usesAppleEnvironmentMode: false))
    }

    @Test
    func appleEnvironmentTransportShadowIsLessProminent() {
        #expect(PlayerCinematicChromePolicy.appleEnvironmentTransportShadowOpacity == 0.06)
        #expect(PlayerCinematicChromePolicy.appleEnvironmentTransportShadowRadius == 8)
        #expect(PlayerCinematicChromePolicy.appleEnvironmentTransportShadowY == 2)
        #expect(PlayerCinematicChromePolicy.resolvedTransportShadowOpacity(usesAppleEnvironmentMode: true) == 0.06)
        #expect(PlayerCinematicChromePolicy.resolvedTransportShadowRadius(usesAppleEnvironmentMode: true) == 8)
        #expect(PlayerCinematicChromePolicy.resolvedTransportShadowY(usesAppleEnvironmentMode: true) == 2)
        #expect(PlayerCinematicChromePolicy.resolvedTransportShadowOpacity(usesAppleEnvironmentMode: false) == 0.24)
        #expect(PlayerCinematicChromePolicy.resolvedTransportShadowRadius(usesAppleEnvironmentMode: false) == 24)
        #expect(PlayerCinematicChromePolicy.resolvedTransportShadowY(usesAppleEnvironmentMode: false) == 10)
    }

    @Test
    func appleEnvironmentSurfaceTreatmentDefersReflectionsToSystemEnvironment() {
        #expect(PlayerCinematicChromePolicy.appleEnvironmentSurfaceRimLineWidth == 1.0)
        #expect(PlayerCinematicChromePolicy.appleEnvironmentSurfaceRimOpacity == 0.24)
        #expect(PlayerCinematicChromePolicy.appleEnvironmentSurfaceInnerShadeLineWidth == 1.0)
        #expect(PlayerCinematicChromePolicy.appleEnvironmentSurfaceInnerShadeOpacity == 0.10)
        #expect(PlayerCinematicChromePolicy.appleEnvironmentWindowContactShadowOpacity == 0.10)
        #expect(PlayerCinematicChromePolicy.appleEnvironmentWindowContactShadowRadius == 28)
        #expect(PlayerCinematicChromePolicy.appleEnvironmentWindowContactShadowY == 14)
        #expect(PlayerCinematicChromePolicy.topBarMetadataOpacity == 0.96)
        #expect(PlayerCinematicChromePolicy.topBarTextShadowOpacity == 0.58)
        #expect(PlayerCinematicChromePolicy.topBarTextShadowRadius == 9)

        #expect(PlayerCinematicChromePolicy.appleEnvironmentSurfaceInnerShadeOpacity < PlayerCinematicChromePolicy.appleEnvironmentSurfaceRimOpacity)
        #expect(PlayerCinematicChromePolicy.appleEnvironmentWindowContactShadowOpacity < 0.12)
    }

    @Test
    func stageStatusBadgeChromeStaysSubtleUntilFallbackIsElevated() {
        #expect(PlayerCinematicChromePolicy.stageStatusBadgeCornerRadius == 22)
        #expect(PlayerCinematicChromePolicy.stageStatusBadgeBackgroundOpacity == 0.28)
        #expect(PlayerCinematicChromePolicy.stageStatusBadgeBorderOpacity == 0.10)
        #expect(PlayerCinematicChromePolicy.stageStatusBadgeElevatedFallbackBackgroundOpacity == 0.46)
        #expect(PlayerCinematicChromePolicy.stageStatusBadgeElevatedFallbackBorderOpacity == 0.18)
        #expect(
            PlayerCinematicChromePolicy.resolvedStageStatusBadgeBackgroundOpacity(
                isElevatedFallback: false
            ) == PlayerCinematicChromePolicy.stageStatusBadgeBackgroundOpacity
        )
        #expect(
            PlayerCinematicChromePolicy.resolvedStageStatusBadgeBackgroundOpacity(
                isElevatedFallback: true
            ) == PlayerCinematicChromePolicy.stageStatusBadgeElevatedFallbackBackgroundOpacity
        )
        #expect(
            PlayerCinematicChromePolicy.resolvedStageStatusBadgeBorderOpacity(
                isElevatedFallback: true
            ) == PlayerCinematicChromePolicy.stageStatusBadgeElevatedFallbackBorderOpacity
        )
    }

    @Test
    func overlayClearanceIsDerivedFromTransportDockDimensions() {
        let expectedDockHeight = PlayerCinematicChromePolicy.controlsDockBottomPadding
            + (PlayerCinematicChromePolicy.transportCardVerticalPadding * 2)
            + PlayerCinematicChromePolicy.quickActionsEstimatedHeight
            + PlayerCinematicChromePolicy.progressHitHeight
            + PlayerCinematicChromePolicy.timeLabelsMinHeight
            + PlayerCinematicChromePolicy.primaryTransportButtonSize
            + (PlayerCinematicChromePolicy.transportInternalSpacing * 2)
            + PlayerCinematicChromePolicy.progressTimeLabelSpacing

        #expect(PlayerCinematicChromePolicy.estimatedTransportDockHeight == expectedDockHeight)
        #expect(
            PlayerCinematicChromePolicy.overlayBottomPaddingAboveTransportDock
                == expectedDockHeight + PlayerCinematicChromePolicy.overlayDockClearance
        )
    }

    @Test
    func autoPlayPromptSitsAboveDockAndSubtitleChrome() {
        #expect(PlayerCinematicChromePolicy.autoPlayPromptZIndex > 0)
    }

    @Test
    func transportInternalSpacing() {
        #expect(PlayerCinematicChromePolicy.transportInternalSpacing == 12)
        #expect(PlayerCinematicChromePolicy.progressTimeLabelSpacing == 6)
        #expect(PlayerCinematicChromePolicy.transportControlSpacing == 28)
        #expect(PlayerCinematicChromePolicy.transportControlDividerHeight == 28)
        #expect(PlayerCinematicChromePolicy.transportControlDividerOpacity == 0.18)
    }

    @Test
    func quickActionPillsStayReadableAtHeadsetDistance() {
        #expect(PlayerCinematicChromePolicy.quickActionPillMinHeight == 42)
        #expect(PlayerCinematicChromePolicy.quickActionPillHorizontalPadding == 14)
        #expect(PlayerCinematicChromePolicy.quickActionPillVerticalPadding == 9)
        #expect(PlayerCinematicChromePolicy.quickActionsEstimatedHeight == 44)
    }

    @Test
    func menusExposeExplicitCloseActionCopy() {
        #expect(PlayerCinematicChromePolicy.closeMenuTitle == "Close Menu")
        #expect(PlayerCinematicChromePolicy.closeMenuIconName == "xmark.circle")
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
        #expect(PlayerCinematicChromePolicy.progressBarIdleHeight == 5)
    }

    @Test
    func progressBarScrubbingHeight() {
        #expect(PlayerCinematicChromePolicy.progressBarScrubbingHeight == 9)
    }

    @Test
    func progressBarKnobSizes() {
        #expect(PlayerCinematicChromePolicy.progressBarIdleKnobSize == 12)
        #expect(PlayerCinematicChromePolicy.progressBarScrubbingKnobSize == 18)
    }
}

@Suite("PlayerCinematicChromePolicy - Window")
struct PlayerCinematicChromePolicyWindowTests {

    @Test
    func windowCornerRadius() {
        #expect(PlayerCinematicChromePolicy.windowCornerRadius == 46)
    }
}

@Suite("PlayerCinematicChromePolicy - Size-Aware Chrome Scaling")
struct PlayerCinematicChromePolicySizeAwareTests {

    @Test
    func unmeasuredContainerFallsBackToFixedConstants() {
        let zero = CGSize.zero
        #expect(PlayerCinematicChromePolicy.chromeScale(containerSize: zero, usesAppleEnvironmentMode: false) == 1)
        #expect(
            PlayerCinematicChromePolicy.resolvedControlsDockBottomPadding(
                usesAppleEnvironmentMode: false,
                containerSize: zero
            ) == PlayerCinematicChromePolicy.controlsDockBottomPadding
        )
        #expect(
            PlayerCinematicChromePolicy.resolvedTransportCardMaxWidth(
                usesAppleEnvironmentMode: false,
                containerSize: zero
            ) == PlayerCinematicChromePolicy.transportCardMaxWidth
        )
        #expect(
            PlayerCinematicChromePolicy.resolvedTopBarMaxWidth(containerSize: zero)
                == PlayerCinematicChromePolicy.topBarMaxWidth
        )
        #expect(
            PlayerCinematicChromePolicy.resolvedSubtitleHiddenControlsBottomPadding(containerSize: zero)
                == PlayerCinematicChromePolicy.subtitleHiddenControlsBottomPadding
        )
        #expect(
            PlayerCinematicChromePolicy.resolvedOverlayBottomPaddingAboveTransportDock(
                containerSize: zero,
                usesAppleEnvironmentMode: false
            ) == PlayerCinematicChromePolicy.overlayBottomPaddingAboveTransportDock
        )
    }

    @Test
    func referenceWindowsReproduceTheTunedChromeExactly() {
        let standard = PlayerCinematicChromePolicy.standardChromeReferenceSize
        #expect(PlayerCinematicChromePolicy.chromeScale(containerSize: standard, usesAppleEnvironmentMode: false) == 1)
        #expect(
            PlayerCinematicChromePolicy.resolvedTransportCardMaxWidth(
                usesAppleEnvironmentMode: false,
                containerSize: standard
            ) == PlayerCinematicChromePolicy.transportCardMaxWidth
        )
        #expect(
            PlayerCinematicChromePolicy.resolvedOverlayBottomPaddingAboveTransportDock(
                containerSize: standard,
                usesAppleEnvironmentMode: false
            ) == PlayerCinematicChromePolicy.overlayBottomPaddingAboveTransportDock
        )

        let expanded = PlayerCinematicChromePolicy.appleEnvironmentExpandedWindowSize
        #expect(PlayerCinematicChromePolicy.chromeScale(containerSize: expanded, usesAppleEnvironmentMode: true) == 1)
        #expect(
            PlayerCinematicChromePolicy.resolvedControlsDockBottomPadding(
                usesAppleEnvironmentMode: true,
                containerSize: expanded
            ) == PlayerCinematicChromePolicy.appleEnvironmentControlsDockBottomPadding
        )
    }

    @Test
    func transportCardNeverOverflowsNarrowWindows() {
        let narrow = CGSize(width: 640, height: 360)
        let maxWidth = PlayerCinematicChromePolicy.resolvedTransportCardMaxWidth(
            usesAppleEnvironmentMode: false,
            containerSize: narrow
        )
        let minWidth = PlayerCinematicChromePolicy.resolvedTransportCardMinWidth(
            usesAppleEnvironmentMode: false,
            containerSize: narrow
        )
        #expect(minWidth <= maxWidth)
        #expect(maxWidth <= narrow.width - PlayerCinematicChromePolicy.controlsDockHorizontalPadding * 2)
    }

    @Test
    func chromeGrowsInLargeWindowsAndButtonsNeverShrinkBelowTapTargets() {
        let large = CGSize(width: 3200, height: 1800)
        #expect(
            PlayerCinematicChromePolicy.resolvedTransportCardMaxWidth(
                usesAppleEnvironmentMode: false,
                containerSize: large
            ) > PlayerCinematicChromePolicy.transportCardMaxWidth
        )
        #expect(
            PlayerCinematicChromePolicy.resolvedTopBarMaxWidth(containerSize: large)
                > PlayerCinematicChromePolicy.topBarMaxWidth
        )
        #expect(
            PlayerCinematicChromePolicy.resolvedPrimaryTransportButtonSize(
                containerSize: large,
                usesAppleEnvironmentMode: false
            ) > PlayerCinematicChromePolicy.primaryTransportButtonSize
        )

        let tiny = CGSize(width: 640, height: 360)
        #expect(
            PlayerCinematicChromePolicy.resolvedTopBarButtonSize(
                containerSize: tiny,
                usesAppleEnvironmentMode: false
            ) >= VPSpace.minTapTarget
        )
        #expect(
            PlayerCinematicChromePolicy.resolvedSecondaryTransportButtonSize(
                containerSize: tiny,
                usesAppleEnvironmentMode: false
            ) >= VPSpace.minTapTarget
        )
    }

    @Test
    func wideShortWindowsScaleOnTheLimitingAxis() {
        // 3:1 window: width alone would suggest growth but height is limiting.
        let wideShort = CGSize(width: 2400, height: 720)
        #expect(PlayerCinematicChromePolicy.chromeScale(containerSize: wideShort, usesAppleEnvironmentMode: false) == 1)
        #expect(
            PlayerCinematicChromePolicy.resolvedControlsDockBottomPadding(
                usesAppleEnvironmentMode: false,
                containerSize: wideShort
            ) == PlayerCinematicChromePolicy.controlsDockBottomPadding
        )
    }
}
