import SwiftUI

enum PlayerCinematicChromePolicy {
    static let transportCardCornerRadius: CGFloat = 22
    static let topScrimHeight: CGFloat = 96
    static let bottomScrimHeight: CGFloat = 132
    static let quickActionsCornerRadius: CGFloat = 20

    // Top-bar utility buttons are gaze targets in visionOS, so keep them at the 60pt floor even
    // inside the dense title row.
    static let topBarButtonSize: CGFloat = VPSpace.minTapTarget
    static let topBarMaxWidth: CGFloat = 980
    static let topBarHorizontalPadding: CGFloat = 52
    // Center transport = WHITE primary action; the dominant control, kept clearly larger than the
    // secondary transport buttons (well above the 60pt minimum tap target).
    static let primaryTransportButtonSize: CGFloat = 72
    // Secondary transport (skip / chapter) = glass; pinned to the 60pt minimum tap target so it
    // stays accessible while reading as subordinate to the primary.
    static let secondaryTransportButtonSize: CGFloat = VPSpace.minTapTarget

    static let controlsDockMaxWidth: CGFloat = 960
    static let quickActionsMaxWidth: CGFloat = 700
    static let transportCardMinWidth: CGFloat = 660
    static let transportCardMaxWidth: CGFloat = 840
    static let controlsDockSpacing: CGFloat = 8
    static let controlsDockHorizontalPadding: CGFloat = 18
    static let controlsDockBottomPadding: CGFloat = 56
    static let appleEnvironmentControlsDockBottomPadding: CGFloat = 14
    static let transportCardHorizontalPadding: CGFloat = 24
    static let transportCardVerticalPadding: CGFloat = 12
    static let transportObsidianScrimOpacity: Double = 0.18
    static let appleEnvironmentTransportCardMinWidth: CGFloat = 540
    static let appleEnvironmentTransportCardMaxWidth: CGFloat = 660
    static let appleEnvironmentTransportCardVerticalPadding: CGFloat = 6
    static let appleEnvironmentTransportInternalSpacing: CGFloat = 7
    static let appleEnvironmentTransportControlSpacing: CGFloat = 18
    static let appleEnvironmentTransportGlassTintOpacity: Double = 0.035
    static let appleEnvironmentTransportObsidianScrimOpacity: Double = 0.12
    static let appleEnvironmentTransportShadowOpacity: Double = 0.06
    static let appleEnvironmentTransportShadowRadius: CGFloat = 8
    static let appleEnvironmentTransportShadowY: CGFloat = 2
    static let topBarButtonObsidianScrimOpacity: Double = 0.26
    static let topBarMetadataOpacity: Double = 0.96
    static let topBarTextShadowOpacity: Double = 0.58
    static let topBarTextShadowRadius: CGFloat = 9
    static let topBarTextShadowY: CGFloat = 1
    static let stageStatusBadgeCornerRadius: CGFloat = 22
    static let stageStatusBadgeBackgroundOpacity: Double = 0.28
    static let stageStatusBadgeBorderOpacity: Double = 0.10
    static let stageStatusBadgeElevatedFallbackBackgroundOpacity: Double = 0.46
    static let stageStatusBadgeElevatedFallbackBorderOpacity: Double = 0.18

    static let transportInternalSpacing: CGFloat = 12
    static let progressTimeLabelSpacing: CGFloat = 6
    static let transportControlSpacing: CGFloat = 28
    static let transportControlDividerHeight: CGFloat = 28
    static let transportControlDividerOpacity: Double = 0.18
    static let quickActionPillMinHeight: CGFloat = 42
    static let quickActionPillHorizontalPadding: CGFloat = 14
    static let quickActionPillVerticalPadding: CGFloat = 9
    static let closeMenuTitle = "Close Menu"
    static let closeMenuIconName = "xmark.circle"
    static let quickActionsEstimatedHeight: CGFloat = 44
    static let progressHitHeight: CGFloat = 22
    static let timeLabelsMinHeight: CGFloat = 18
    static let subtitleHiddenControlsBottomPadding: CGFloat = 90
    static let autoPlayHiddenControlsBottomPadding: CGFloat = 150
    static let autoPlayHiddenControlsWithSubtitlesBottomPadding: CGFloat = 224
    static let overlayDockClearance: CGFloat = 32
    static let autoPlaySubtitleSeparation: CGFloat = 94
    static let autoPlayPromptZIndex: Double = 1
    static let skipBackInterval: Int = 10
    static let skipForwardInterval: Int = 10

    static let progressBarIdleHeight: CGFloat = 5
    static let progressBarScrubbingHeight: CGFloat = 9
    static let progressBarIdleKnobSize: CGFloat = 12
    static let progressBarScrubbingKnobSize: CGFloat = 18

    static let windowCornerRadius: CGFloat = 46
    static let appleEnvironmentSurfaceRimLineWidth: CGFloat = 1.0
    static let appleEnvironmentSurfaceRimOpacity: Double = 0.24
    static let appleEnvironmentSurfaceInnerShadeLineWidth: CGFloat = 1.0
    static let appleEnvironmentSurfaceInnerShadeOpacity: Double = 0.10
    static let appleEnvironmentWindowContactShadowOpacity: Double = 0.10
    static let appleEnvironmentWindowContactShadowRadius: CGFloat = 28
    static let appleEnvironmentWindowContactShadowY: CGFloat = 14
    static let appleEnvironmentWindowMinimumSize = CGSize(width: 640, height: 360)
    static let appleEnvironmentWindowMaximumSize = CGSize(width: 3840, height: 3840)
    static let appleEnvironmentExpandedWindowSize = CGSize(width: 2400, height: 1350)
    static let appleEnvironmentExpansionRelaxDelay: Duration = .milliseconds(250)

    static var estimatedTransportDockHeight: CGFloat {
        controlsDockBottomPadding
            + (transportCardVerticalPadding * 2)
            + quickActionsEstimatedHeight
            + progressHitHeight
            + timeLabelsMinHeight
            + primaryTransportButtonSize
            + (transportInternalSpacing * 2)
            + progressTimeLabelSpacing
    }

    static var overlayBottomPaddingAboveTransportDock: CGFloat {
        estimatedTransportDockHeight + overlayDockClearance
    }

    static func resolvedControlsDockBottomPadding(usesAppleEnvironmentMode: Bool) -> CGFloat {
        usesAppleEnvironmentMode ? appleEnvironmentControlsDockBottomPadding : controlsDockBottomPadding
    }

    static func resolvedTransportCardMinWidth(usesAppleEnvironmentMode: Bool) -> CGFloat {
        usesAppleEnvironmentMode ? appleEnvironmentTransportCardMinWidth : transportCardMinWidth
    }

    static func resolvedTransportCardMaxWidth(usesAppleEnvironmentMode: Bool) -> CGFloat {
        usesAppleEnvironmentMode ? appleEnvironmentTransportCardMaxWidth : transportCardMaxWidth
    }

    static func resolvedTransportObsidianScrimOpacity(usesAppleEnvironmentMode: Bool) -> Double {
        usesAppleEnvironmentMode ? appleEnvironmentTransportObsidianScrimOpacity : transportObsidianScrimOpacity
    }

    static func resolvedTransportCardVerticalPadding(usesAppleEnvironmentMode: Bool) -> CGFloat {
        usesAppleEnvironmentMode ? appleEnvironmentTransportCardVerticalPadding : transportCardVerticalPadding
    }

    static func resolvedTransportInternalSpacing(usesAppleEnvironmentMode: Bool) -> CGFloat {
        usesAppleEnvironmentMode ? appleEnvironmentTransportInternalSpacing : transportInternalSpacing
    }

    static func resolvedTransportControlSpacing(usesAppleEnvironmentMode: Bool) -> CGFloat {
        usesAppleEnvironmentMode ? appleEnvironmentTransportControlSpacing : transportControlSpacing
    }

    static func resolvedTransportGlassTintOpacity(usesAppleEnvironmentMode: Bool) -> Double {
        usesAppleEnvironmentMode ? appleEnvironmentTransportGlassTintOpacity : 0.11
    }

    static func resolvedTransportUsesLightweightMaterial(usesAppleEnvironmentMode: Bool) -> Bool {
        usesAppleEnvironmentMode
    }

    static func resolvedStageStatusBadgeBackgroundOpacity(isElevatedFallback: Bool) -> Double {
        isElevatedFallback ? stageStatusBadgeElevatedFallbackBackgroundOpacity : stageStatusBadgeBackgroundOpacity
    }

    static func resolvedStageStatusBadgeBorderOpacity(isElevatedFallback: Bool) -> Double {
        isElevatedFallback ? stageStatusBadgeElevatedFallbackBorderOpacity : stageStatusBadgeBorderOpacity
    }

    static func resolvedTransportShadowOpacity(usesAppleEnvironmentMode: Bool) -> Double {
        usesAppleEnvironmentMode ? appleEnvironmentTransportShadowOpacity : 0.24
    }

    static func resolvedTransportShadowRadius(usesAppleEnvironmentMode: Bool) -> CGFloat {
        usesAppleEnvironmentMode ? appleEnvironmentTransportShadowRadius : 24
    }

    static func resolvedTransportShadowY(usesAppleEnvironmentMode: Bool) -> CGFloat {
        usesAppleEnvironmentMode ? appleEnvironmentTransportShadowY : 10
    }

    static func subtitleDynamicBottomPaddingExtra(fontSize: CGFloat) -> CGFloat {
        guard fontSize.isFinite else { return 0 }
        return max(0, fontSize - 24) * 1.4
    }

    // MARK: - Letterbox-Aware Subtitle Placement
    //
    // With an aspect-fit video (freeform / Apple Environment gravity) whose
    // ratio is wider than the window's, the picture is letterboxed between
    // horizontal bars. Subtitles must sit inside the picture rather than
    // float in the bottom bar, so their bottom padding is floored at the bar
    // height plus a small clearance. Window-docked chrome (transport dock,
    // title bar) intentionally ignores this floor.

    /// Clearance between the bottom edge of the displayed video and the
    /// subtitle card when the letterbox floor is the binding constraint.
    static let subtitleLetterboxClearance: CGFloat = 20

    /// Height of one horizontal letterbox bar for an aspect-fit video
    /// centered in `containerSize`. Zero when unmeasured, when the video
    /// ratio is unknown or degenerate, or when the fitted video fills the
    /// container height (matching or pillarboxed aspect).
    static func letterboxBarHeight(
        containerSize: CGSize,
        videoAspectRatio: CGFloat?
    ) -> CGFloat {
        guard let videoAspectRatio, videoAspectRatio.isFinite, videoAspectRatio > 0,
              containerSize.width.isFinite, containerSize.height.isFinite,
              containerSize.width > 0, containerSize.height > 0 else {
            return 0
        }
        let fitted = VideoFittingPolicy.fittedSize(for: containerSize, ratio: videoAspectRatio)
        return max(0, (containerSize.height - fitted.height) / 2)
    }

    // MARK: - Size-Aware Chrome Scaling
    //
    // The fixed constants above were tuned against a 1280x720 window (standard
    // chrome) and the 2400x1350 expanded window (Apple Environment chrome).
    // These resolvers derive live metrics from the measured window size so the
    // chrome tracks aspect-ratio presets, freeform resizes, and the expanded
    // Apple Environment window. A non-positive `containerSize` (first layout,
    // before measurement) always reproduces the fixed base values exactly.

    /// Reference window the standard chrome constants were designed against.
    static let standardChromeReferenceSize = CGSize(width: 1280, height: 720)
    /// Chrome shrinks to at most 72% of its tuned metrics in small windows…
    static let chromeScaleLowerBound: CGFloat = 0.72
    /// …and grows to at most 170% in very large ones.
    static let chromeScaleUpperBound: CGFloat = 1.7
    /// Top bar tracks the window width in large windows instead of floating in
    /// a fixed 980pt centered island.
    static let topBarWidthFraction: CGFloat = 0.94
    /// Fixed glyph sizes the transport buttons were tuned with.
    static let primaryTransportGlyphSize: CGFloat = 24
    static let secondaryTransportGlyphSize: CGFloat = 20

    static func chromeReferenceSize(usesAppleEnvironmentMode: Bool) -> CGSize {
        usesAppleEnvironmentMode ? appleEnvironmentExpandedWindowSize : standardChromeReferenceSize
    }

    /// Uniform chrome scale from the limiting window axis, so wide-short and
    /// tall-narrow windows never scale chrome past what fits.
    static func chromeScale(containerSize: CGSize, usesAppleEnvironmentMode: Bool) -> CGFloat {
        guard containerSize.width.isFinite, containerSize.height.isFinite,
              containerSize.width > 0, containerSize.height > 0 else {
            return 1
        }
        let reference = chromeReferenceSize(usesAppleEnvironmentMode: usesAppleEnvironmentMode)
        let limitingFactor = min(
            containerSize.width / reference.width,
            containerSize.height / reference.height
        )
        return min(max(limitingFactor, chromeScaleLowerBound), chromeScaleUpperBound)
    }

    /// Vertical-only scale for bottom insets that should track window height.
    static func chromeVerticalScale(containerSize: CGSize, usesAppleEnvironmentMode: Bool) -> CGFloat {
        guard containerSize.height.isFinite, containerSize.height > 0 else { return 1 }
        let reference = chromeReferenceSize(usesAppleEnvironmentMode: usesAppleEnvironmentMode)
        let factor = containerSize.height / reference.height
        return min(max(factor, chromeScaleLowerBound), chromeScaleUpperBound)
    }

    /// The transport card may never exceed the window minus the dock insets.
    private static func transportCardWidthCap(containerWidth: CGFloat) -> CGFloat {
        max(containerWidth - controlsDockHorizontalPadding * 2, 1)
    }

    static func resolvedControlsDockBottomPadding(
        usesAppleEnvironmentMode: Bool,
        containerSize: CGSize
    ) -> CGFloat {
        resolvedControlsDockBottomPadding(usesAppleEnvironmentMode: usesAppleEnvironmentMode)
            * chromeVerticalScale(containerSize: containerSize, usesAppleEnvironmentMode: usesAppleEnvironmentMode)
    }

    static func resolvedTransportCardMinWidth(
        usesAppleEnvironmentMode: Bool,
        containerSize: CGSize
    ) -> CGFloat {
        let base = resolvedTransportCardMinWidth(usesAppleEnvironmentMode: usesAppleEnvironmentMode)
        guard containerSize.width > 0 else { return base }
        let scaled = base * chromeScale(containerSize: containerSize, usesAppleEnvironmentMode: usesAppleEnvironmentMode)
        return min(scaled, transportCardWidthCap(containerWidth: containerSize.width))
    }

    static func resolvedTransportCardMaxWidth(
        usesAppleEnvironmentMode: Bool,
        containerSize: CGSize
    ) -> CGFloat {
        let base = resolvedTransportCardMaxWidth(usesAppleEnvironmentMode: usesAppleEnvironmentMode)
        guard containerSize.width > 0 else { return base }
        let scaled = base * chromeScale(containerSize: containerSize, usesAppleEnvironmentMode: usesAppleEnvironmentMode)
        return max(
            min(scaled, transportCardWidthCap(containerWidth: containerSize.width)),
            resolvedTransportCardMinWidth(usesAppleEnvironmentMode: usesAppleEnvironmentMode, containerSize: containerSize)
        )
    }

    static func resolvedTopBarMaxWidth(containerSize: CGSize) -> CGFloat {
        guard containerSize.width.isFinite, containerSize.width > 0 else { return topBarMaxWidth }
        return max(topBarMaxWidth, containerSize.width * topBarWidthFraction)
    }

    static func resolvedTopBarButtonSize(
        containerSize: CGSize,
        usesAppleEnvironmentMode: Bool
    ) -> CGFloat {
        // Grows with the window; never shrinks below the gaze tap-target floor.
        max(
            topBarButtonSize,
            topBarButtonSize * chromeScale(containerSize: containerSize, usesAppleEnvironmentMode: usesAppleEnvironmentMode)
        )
    }

    static func resolvedPrimaryTransportButtonSize(
        containerSize: CGSize,
        usesAppleEnvironmentMode: Bool
    ) -> CGFloat {
        max(
            primaryTransportButtonSize,
            primaryTransportButtonSize * chromeScale(containerSize: containerSize, usesAppleEnvironmentMode: usesAppleEnvironmentMode)
        )
    }

    static func resolvedSecondaryTransportButtonSize(
        containerSize: CGSize,
        usesAppleEnvironmentMode: Bool
    ) -> CGFloat {
        max(
            secondaryTransportButtonSize,
            secondaryTransportButtonSize * chromeScale(containerSize: containerSize, usesAppleEnvironmentMode: usesAppleEnvironmentMode)
        )
    }

    static func resolvedPrimaryTransportGlyphSize(
        containerSize: CGSize,
        usesAppleEnvironmentMode: Bool
    ) -> CGFloat {
        max(
            primaryTransportGlyphSize,
            primaryTransportGlyphSize * chromeScale(containerSize: containerSize, usesAppleEnvironmentMode: usesAppleEnvironmentMode)
        )
    }

    static func resolvedSecondaryTransportGlyphSize(
        containerSize: CGSize,
        usesAppleEnvironmentMode: Bool
    ) -> CGFloat {
        max(
            secondaryTransportGlyphSize,
            secondaryTransportGlyphSize * chromeScale(containerSize: containerSize, usesAppleEnvironmentMode: usesAppleEnvironmentMode)
        )
    }

    static func resolvedSubtitleHiddenControlsBottomPadding(
        containerSize: CGSize,
        usesAppleEnvironmentMode: Bool = false
    ) -> CGFloat {
        subtitleHiddenControlsBottomPadding
            * chromeVerticalScale(containerSize: containerSize, usesAppleEnvironmentMode: usesAppleEnvironmentMode)
    }

    static func resolvedAutoPlayHiddenControlsBottomPadding(
        containerSize: CGSize,
        hasVisibleSubtitles: Bool,
        usesAppleEnvironmentMode: Bool = false
    ) -> CGFloat {
        let base = hasVisibleSubtitles
            ? autoPlayHiddenControlsWithSubtitlesBottomPadding
            : autoPlayHiddenControlsBottomPadding
        return base * chromeVerticalScale(containerSize: containerSize, usesAppleEnvironmentMode: usesAppleEnvironmentMode)
    }

    /// Size-aware companion to `overlayBottomPaddingAboveTransportDock`.
    /// Reproduces the fixed 298pt value exactly at the standard reference size
    /// and when unmeasured; otherwise tracks the scaled dock metrics so
    /// subtitles and the auto-play prompt stay just above the live dock.
    static func resolvedOverlayBottomPaddingAboveTransportDock(
        containerSize: CGSize,
        usesAppleEnvironmentMode: Bool
    ) -> CGFloat {
        guard containerSize.height > 0 else { return overlayBottomPaddingAboveTransportDock }
        let scale = chromeScale(containerSize: containerSize, usesAppleEnvironmentMode: usesAppleEnvironmentMode)
        let dockContentHeight = (resolvedTransportCardVerticalPadding(usesAppleEnvironmentMode: usesAppleEnvironmentMode) * 2)
            + quickActionsEstimatedHeight
            + progressHitHeight
            + timeLabelsMinHeight
            + (resolvedTransportInternalSpacing(usesAppleEnvironmentMode: usesAppleEnvironmentMode) * 2)
            + progressTimeLabelSpacing
        return resolvedControlsDockBottomPadding(usesAppleEnvironmentMode: usesAppleEnvironmentMode, containerSize: containerSize)
            + dockContentHeight * scale
            + resolvedPrimaryTransportButtonSize(containerSize: containerSize, usesAppleEnvironmentMode: usesAppleEnvironmentMode)
            + overlayDockClearance * scale
    }
}

enum PlayerInfoPillScrollCuePolicy {
    static let trailingFadeStart = 0.93
    static let trailingFadeEnd = 1.0
}
