import Foundation
import Testing
@testable import VPStudio

@Suite("PlayerGesturePolicy Double-Tap Constants")
struct PlayerGesturePolicyDoubleTapTests {
    @Test("Double tap max interval")
    func doubleTapMaxInterval() {
        #expect(PlayerGesturePolicy.doubleTapMaxInterval == 0.35)
    }

    @Test("Double tap seek back seconds")
    func doubleTapSeekBackSeconds() {
        #expect(PlayerGesturePolicy.doubleTapSeekBackSeconds == -10)
    }

    @Test("Double tap seek forward seconds")
    func doubleTapSeekForwardSeconds() {
        #expect(PlayerGesturePolicy.doubleTapSeekForwardSeconds == TimeInterval(PlayerCinematicChromePolicy.skipForwardInterval))
    }

    @Test("Double tap zone fraction")
    func doubleTapZoneFraction() {
        #expect(PlayerGesturePolicy.doubleTapZoneFraction == 0.35)
    }

    @Test("Seek back is negative, forward is positive")
    func seekDirections() {
        #expect(PlayerGesturePolicy.doubleTapSeekBackSeconds < 0)
        #expect(PlayerGesturePolicy.doubleTapSeekForwardSeconds > 0)
    }
}

@Suite("PlayerGesturePolicy Double-Tap Seek Offset")
struct PlayerGesturePolicyDoubleTapSeekOffsetTestsViewsViewsplayergesturepolicytests {
    @Test("Tap on far left returns seek back offset")
    func tapFarLeft() {
        let result = PlayerGesturePolicy.doubleTapSeekOffset(tapX: 0, surfaceWidth: 1000)
        #expect(result == -10)
    }

    @Test("Tap on far right returns seek forward offset")
    func tapFarRight() {
        let result = PlayerGesturePolicy.doubleTapSeekOffset(tapX: 1000, surfaceWidth: 1000)
        #expect(result == TimeInterval(PlayerCinematicChromePolicy.skipForwardInterval))
    }

    @Test("Tap in center dead zone returns nil")
    func tapInCenter() {
        let result = PlayerGesturePolicy.doubleTapSeekOffset(tapX: 500, surfaceWidth: 1000)
        #expect(result == nil)
    }

    @Test("Tap at left boundary of left zone")
    func tapAtLeftBoundary() {
        let result = PlayerGesturePolicy.doubleTapSeekOffset(tapX: 100, surfaceWidth: 1000)
        #expect(result == -10)
    }

    @Test("Tap at right boundary of right zone")
    func tapAtRightBoundary() {
        let result = PlayerGesturePolicy.doubleTapSeekOffset(tapX: 900, surfaceWidth: 1000)
        #expect(result == TimeInterval(PlayerCinematicChromePolicy.skipForwardInterval))
    }

    @Test("Tap just inside left zone")
    func tapJustInsideLeftZone() {
        let result = PlayerGesturePolicy.doubleTapSeekOffset(tapX: 349, surfaceWidth: 1000)
        #expect(result == -10)
    }

    @Test("Tap just inside right zone")
    func tapJustInsideRightZone() {
        let result = PlayerGesturePolicy.doubleTapSeekOffset(tapX: 651, surfaceWidth: 1000)
        #expect(result == TimeInterval(PlayerCinematicChromePolicy.skipForwardInterval))
    }

    @Test("Zero width returns nil")
    func zeroWidth() {
        let result = PlayerGesturePolicy.doubleTapSeekOffset(tapX: 100, surfaceWidth: 0)
        #expect(result == nil)
    }

    @Test("Negative width returns nil")
    func negativeWidth() {
        let result = PlayerGesturePolicy.doubleTapSeekOffset(tapX: 100, surfaceWidth: -100)
        #expect(result == nil)
    }

    @Test("Seek offset works with various surface widths")
    func variousSurfaceWidths() {
        let resultLeft = PlayerGesturePolicy.doubleTapSeekOffset(tapX: 0, surfaceWidth: 800)
        #expect(resultLeft == -10)

        let resultRight = PlayerGesturePolicy.doubleTapSeekOffset(tapX: 800, surfaceWidth: 800)
        #expect(resultRight == TimeInterval(PlayerCinematicChromePolicy.skipForwardInterval))

        let resultCenter = PlayerGesturePolicy.doubleTapSeekOffset(tapX: 400, surfaceWidth: 800)
        #expect(resultCenter == nil)
    }

    @Test("Fraction boundaries are correct")
    func fractionBoundaries() {
        let width: Double = 1000
        let leftFraction = PlayerGesturePolicy.doubleTapZoneFraction
        let rightFraction = 1 - PlayerGesturePolicy.doubleTapZoneFraction

        let leftResult = PlayerGesturePolicy.doubleTapSeekOffset(tapX: leftFraction * width - 1, surfaceWidth: width)
        #expect(leftResult == -10)

        let centerResult = PlayerGesturePolicy.doubleTapSeekOffset(tapX: width / 2, surfaceWidth: width)
        #expect(centerResult == nil)

        let rightResult = PlayerGesturePolicy.doubleTapSeekOffset(tapX: rightFraction * width + 1, surfaceWidth: width)
        #expect(rightResult == TimeInterval(PlayerCinematicChromePolicy.skipForwardInterval))
    }
}

@Suite("PlayerGesturePolicy Seek Direction")
struct PlayerGesturePolicySeekDirectionTestsViewsViewsplayergesturepolicytests {
    @Test("Negative offset returns backward")
    func negativeOffset() {
        #expect(PlayerGesturePolicy.seekDirection(for: -10) == .backward)
    }

    @Test("Positive offset returns forward")
    func positiveOffset() {
        #expect(PlayerGesturePolicy.seekDirection(for: 30) == .forward)
    }

    @Test("Zero offset returns forward")
    func zeroOffset() {
        #expect(PlayerGesturePolicy.seekDirection(for: 0) == .forward)
    }

    @Test("Seek direction is consistent")
    func consistentSeekDirection() {
        for offset: TimeInterval in [-100, -50, -10, -1, 1, 10, 50, 100] {
            let direction = PlayerGesturePolicy.seekDirection(for: offset)
            if offset < 0 {
                #expect(direction == .backward)
            } else {
                #expect(direction == .forward)
            }
        }
    }
}

@Suite("PlayerGesturePolicy Swipe Constants")
struct PlayerGesturePolicySwipeTests {
    @Test("Swipe minimum distance")
    func swipeMinimumDistance() {
        #expect(PlayerGesturePolicy.swipeMinimumDistance == 30.0)
    }

    @Test("Swipe max horizontal deviation")
    func swipeMaxHorizontalDeviation() {
        #expect(PlayerGesturePolicy.swipeMaxHorizontalDeviation == 40.0)
    }

    @Test("Swipe minimum distance is positive")
    func swipeMinimumPositive() {
        #expect(PlayerGesturePolicy.swipeMinimumDistance > 0)
    }

    @Test("Horizontal deviation is positive")
    func horizontalDeviationPositive() {
        #expect(PlayerGesturePolicy.swipeMaxHorizontalDeviation > 0)
    }
}
