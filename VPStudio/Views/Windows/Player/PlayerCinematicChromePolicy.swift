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
    static let skipBackInterval: Int = 10
    static let skipForwardInterval: Int = 10

    static let progressBarIdleHeight: CGFloat = 4
    static let progressBarScrubbingHeight: CGFloat = 8

    static let windowCornerRadius: CGFloat = 28

}
