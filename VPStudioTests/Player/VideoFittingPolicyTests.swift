import Testing
import CoreGraphics
@testable import VPStudio

@Suite("VideoFittingPolicy")
struct VideoFittingPolicyTests {
    @Test("Fitted size wider container than video")
    func widerContainer() {
        let container = CGSize(width: 1000, height: 500)
        let result = VideoFittingPolicy.fittedSize(for: container, ratio: 16.0/9.0)
        #expect(result.height == 500)
        #expect(result.width < 1000)
        #expect(abs((result.width / result.height) - (16.0/9.0)) < 0.001)
    }

    @Test("Fitted size taller container than video")
    func tallerContainer() {
        let container = CGSize(width: 500, height: 1000)
        let result = VideoFittingPolicy.fittedSize(for: container, ratio: 16.0/9.0)
        #expect(result.width == 500)
        #expect(result.height < 1000)
        #expect(abs((result.width / result.height) - (16.0/9.0)) < 0.001)
    }

    @Test("Fitted size matches container ratio")
    func matchesRatio() {
        let container = CGSize(width: 800, height: 600)
        let ratio: CGFloat = 16.0/9.0
        let result = VideoFittingPolicy.fittedSize(for: container, ratio: ratio)
        #expect(abs((result.width / result.height) - ratio) < 0.001)
    }

    @Test("Zero height container returns container size")
    func zeroHeight() {
        let container = CGSize(width: 1000, height: 0)
        #expect(VideoFittingPolicy.fittedSize(for: container, ratio: 16.0/9.0) == container)
    }

    @Test("Zero ratio returns container size")
    func zeroRatio() {
        let container = CGSize(width: 1000, height: 500)
        #expect(VideoFittingPolicy.fittedSize(for: container, ratio: 0) == container)
    }

    @Test("Negative height returns container size")
    func negativeHeight() {
        let container = CGSize(width: 1000, height: -100)
        #expect(VideoFittingPolicy.fittedSize(for: container, ratio: 16.0/9.0) == container)
    }

    @Test("Negative ratio returns container size")
    func negativeRatio() {
        let container = CGSize(width: 1000, height: 500)
        #expect(VideoFittingPolicy.fittedSize(for: container, ratio: -1.0) == container)
    }

    @Test("Square video in square container")
    func squareVideoSquareContainer() {
        let container = CGSize(width: 500, height: 500)
        let result = VideoFittingPolicy.fittedSize(for: container, ratio: 1.0)
        #expect(result.width == 500)
        #expect(result.height == 500)
    }

    @Test("Ultrawide video in ultrawide container")
    func ultrawideVideo() {
        let container = CGSize(width: 2000, height: 400)
        let result = VideoFittingPolicy.fittedSize(for: container, ratio: 21.0/9.0)
        #expect(result.height == 400)
        #expect(abs((result.width / result.height) - (21.0/9.0)) < 0.001)
    }
}
