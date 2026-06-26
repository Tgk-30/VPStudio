import SwiftUI

enum PlayerCinematicChromePolicy {
    static let transportCardCornerRadius: CGFloat = 26
    static let topScrimHeight: CGFloat = 96
    static let bottomScrimHeight: CGFloat = 132
    static let quickActionsCornerRadius: CGFloat = 20

    // Top-bar utility buttons are dense in-content controls in a crowded title row; raised toward
    // the 60pt floor without overflowing the row (>= the 44pt dense-control minimum).
    static let topBarButtonSize: CGFloat = 50
    // Center transport = WHITE primary action; the dominant control, kept clearly larger than the
    // secondary transport buttons (well above the 60pt minimum tap target).
    static let primaryTransportButtonSize: CGFloat = 72
    // Secondary transport (skip / chapter) = glass; pinned to the 60pt minimum tap target so it
    // stays accessible while reading as subordinate to the primary.
    static let secondaryTransportButtonSize: CGFloat = VPSpace.minTapTarget

    static let controlsDockMaxWidth: CGFloat = 860
    static let quickActionsMaxWidth: CGFloat = 640
    static let transportCardMaxWidth: CGFloat = 780
    static let controlsDockSpacing: CGFloat = 8
    static let controlsDockHorizontalPadding: CGFloat = 18
    static let controlsDockBottomPadding: CGFloat = 56
    static let transportCardHorizontalPadding: CGFloat = 20
    static let transportCardVerticalPadding: CGFloat = 12

    static let transportInternalSpacing: CGFloat = 10
    static let quickActionsEstimatedHeight: CGFloat = 32
    static let progressHitHeight: CGFloat = 22
    static let timeLabelsMinHeight: CGFloat = 18
    static let subtitleHiddenControlsBottomPadding: CGFloat = 90
    static let autoPlayHiddenControlsBottomPadding: CGFloat = 150
    static let autoPlayHiddenControlsWithSubtitlesBottomPadding: CGFloat = 224
    static let overlayDockClearance: CGFloat = 32
    static let autoPlaySubtitleSeparation: CGFloat = 94
    static let skipBackInterval: Int = 10
    static let skipForwardInterval: Int = 10

    static let progressBarIdleHeight: CGFloat = 4
    static let progressBarScrubbingHeight: CGFloat = 8

    static let windowCornerRadius: CGFloat = 28

    static var estimatedTransportDockHeight: CGFloat {
        controlsDockBottomPadding
            + (transportCardVerticalPadding * 2)
            + quickActionsEstimatedHeight
            + progressHitHeight
            + timeLabelsMinHeight
            + primaryTransportButtonSize
            + (transportInternalSpacing * 3)
    }

    static var overlayBottomPaddingAboveTransportDock: CGFloat {
        estimatedTransportDockHeight + overlayDockClearance
    }

    static func subtitleDynamicBottomPaddingExtra(fontSize: CGFloat) -> CGFloat {
        guard fontSize.isFinite else { return 0 }
        return max(0, fontSize - 24) * 1.4
    }
}
