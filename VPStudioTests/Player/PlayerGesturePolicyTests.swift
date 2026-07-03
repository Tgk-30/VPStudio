import Foundation
import Testing
@testable import VPStudio

@Suite("PlayerGesturePolicy - Double Tap Constants")
struct PlayerGesturePolicyDoubleTapConstantsTests {

    @Test
    func doubleTapMaxInterval() {
        #expect(PlayerGesturePolicy.doubleTapMaxInterval == 0.35)
    }

    @Test
    func doubleTapSeekBackSeconds() {
        #expect(PlayerGesturePolicy.doubleTapSeekBackSeconds == -10)
    }

    @Test
    func doubleTapSeekForwardSeconds() {
        #expect(PlayerGesturePolicy.doubleTapSeekForwardSeconds == TimeInterval(PlayerCinematicChromePolicy.skipForwardInterval))
    }

    @Test
    func doubleTapZoneFraction() {
        #expect(PlayerGesturePolicy.doubleTapZoneFraction == 0.35)
    }
}

@Suite("PlayerGesturePolicy - Double Tap Seek Offset")
struct PlayerGesturePolicyDoubleTapSeekOffsetTests {

    @Test
    func leftZoneSeeksBackward() {
        let offset = PlayerGesturePolicy.doubleTapSeekOffset(tapX: 100, surfaceWidth: 1000)
        #expect(offset == -10)
    }

    @Test
    func rightZoneSeeksForward() {
        let offset = PlayerGesturePolicy.doubleTapSeekOffset(tapX: 900, surfaceWidth: 1000)
        #expect(offset == TimeInterval(PlayerCinematicChromePolicy.skipForwardInterval))
    }

    @Test
    func centerZoneReturnsNil() {
        let offset = PlayerGesturePolicy.doubleTapSeekOffset(tapX: 500, surfaceWidth: 1000)
        #expect(offset == nil)
    }

    @Test
    func nearLeftEdgeSeeksBackward() {
        let offset = PlayerGesturePolicy.doubleTapSeekOffset(tapX: 10, surfaceWidth: 1000)
        #expect(offset == -10)
    }

    @Test
    func nearRightEdgeSeeksForward() {
        let offset = PlayerGesturePolicy.doubleTapSeekOffset(tapX: 990, surfaceWidth: 1000)
        #expect(offset == TimeInterval(PlayerCinematicChromePolicy.skipForwardInterval))
    }

    @Test
    func zeroSurfaceWidthReturnsNil() {
        let offset = PlayerGesturePolicy.doubleTapSeekOffset(tapX: 100, surfaceWidth: 0)
        #expect(offset == nil)
    }

    @Test
    func negativeSurfaceWidthReturnsNil() {
        let offset = PlayerGesturePolicy.doubleTapSeekOffset(tapX: 100, surfaceWidth: -100)
        #expect(offset == nil)
    }

    @Test
    func outOfBoundsTapXReturnsNil() {
        #expect(PlayerGesturePolicy.doubleTapSeekOffset(tapX: -1, surfaceWidth: 1000) == nil)
        #expect(PlayerGesturePolicy.doubleTapSeekOffset(tapX: 1001, surfaceWidth: 1000) == nil)
    }

    @Test
    func atBoundaryLeftZoneThreshold() {
        let offset = PlayerGesturePolicy.doubleTapSeekOffset(tapX: 350, surfaceWidth: 1000)
        #expect(offset == -10)
    }

    @Test
    func atBoundaryRightZoneThreshold() {
        let offset = PlayerGesturePolicy.doubleTapSeekOffset(tapX: 650, surfaceWidth: 1000)
        #expect(offset == TimeInterval(PlayerCinematicChromePolicy.skipForwardInterval))
    }
}

@Suite("PlayerGesturePolicy - Seek Direction")
struct PlayerGesturePolicySeekDirectionTests {

    @Test
    func negativeOffsetIsBackward() {
        #expect(PlayerGesturePolicy.seekDirection(for: -10) == .backward)
    }

    @Test
    func positiveOffsetIsForward() {
        #expect(PlayerGesturePolicy.seekDirection(for: 30) == .forward)
    }

    @Test
    func zeroOffsetIsForward() {
        #expect(PlayerGesturePolicy.seekDirection(for: 0) == .forward)
    }
}

@Suite("PlayerGesturePolicy - Swipe Thresholds")
struct PlayerGesturePolicySwipeThresholdsTests {

    @Test
    func swipeMinimumDistance() {
        #expect(PlayerGesturePolicy.swipeMinimumDistance == 30.0)
    }

    @Test
    func swipeMaxHorizontalDeviation() {
        #expect(PlayerGesturePolicy.swipeMaxHorizontalDeviation == 40.0)
    }
}

@Suite("PlayerGesturePolicy - Seek Direction Equatable")
struct PlayerGesturePolicySeekDirectionEquatableTests {

    @Test
    func backwardNotEqualToForward() {
        #expect(PlayerGesturePolicy.SeekDirection.backward != .forward)
    }

    @Test
    func backwardEqualToBackward() {
        #expect(PlayerGesturePolicy.SeekDirection.backward == .backward)
    }

    @Test
    func forwardEqualToForward() {
        #expect(PlayerGesturePolicy.SeekDirection.forward == .forward)
    }
}
