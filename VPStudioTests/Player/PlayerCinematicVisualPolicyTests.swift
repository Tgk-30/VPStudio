import Foundation
import Testing
@testable import VPStudio

@Suite("PlayerCinematicVisualPolicy - Symbol Names")
struct PlayerCinematicVisualPolicySymbolNamesTests {

    @Test
    func backSymbolName() {
        #expect(PlayerCinematicVisualPolicy.backSymbolName == "chevron.left")
    }

    @Test
    func menuSymbolName() {
        #expect(PlayerCinematicVisualPolicy.menuSymbolName == "ellipsis")
    }

    @Test
    func subtitlesSymbolName() {
        #expect(PlayerCinematicVisualPolicy.subtitlesSymbolName == "captions.bubble.fill")
    }

    @Test
    func audioSymbolName() {
        #expect(PlayerCinematicVisualPolicy.audioSymbolName == "speaker.wave.2.fill")
    }

    @Test
    func qualitySymbolName() {
        #expect(PlayerCinematicVisualPolicy.qualitySymbolName == "line.3.horizontal.decrease.circle.fill")
    }

    @Test
    func streamListSymbolName() {
        #expect(PlayerCinematicVisualPolicy.streamListSymbolName == "rectangle.stack.badge.play.fill")
    }

    @Test
    func previousChapterSymbolName() {
        #expect(PlayerCinematicVisualPolicy.previousChapterSymbolName == "backward.end.fill")
    }

    @Test
    func nextChapterSymbolName() {
        #expect(PlayerCinematicVisualPolicy.nextChapterSymbolName == "forward.end.fill")
    }

    @Test
    func skipBackSymbolName() {
        #expect(PlayerCinematicVisualPolicy.skipBackSymbolName == "gobackward.10")
    }

    @Test
    func skipForwardSymbolName() {
        #expect(PlayerCinematicVisualPolicy.skipForwardSymbolName == "goforward.10")
    }
}

@Suite("PlayerCinematicVisualPolicy - Icon Surface Opacity")
struct PlayerCinematicVisualPolicyIconSurfaceOpacityTests {

    @Test
    func iconSurfaceBorderOpacity() {
        #expect(PlayerCinematicVisualPolicy.iconSurfaceBorderOpacity == 0.30)
    }

    @Test
    func iconSurfaceHighlightOpacity() {
        #expect(PlayerCinematicVisualPolicy.iconSurfaceHighlightOpacity == 0.22)
    }

    @Test
    func iconSurfaceShadowOpacity() {
        #expect(PlayerCinematicVisualPolicy.iconSurfaceShadowOpacity == 0.44)
    }

    @Test
    func activeControlBorderOpacity() {
        #expect(PlayerCinematicVisualPolicy.activeControlBorderOpacity == 0.88)
    }
}

@Suite("PlayerCinematicVisualPolicy - Progress Track Opacity")
struct PlayerCinematicVisualPolicyProgressTrackOpacityTests {

    @Test
    func progressTrackOpacity() {
        #expect(PlayerCinematicVisualPolicy.progressTrackOpacity == 0.18)
    }

    @Test
    func progressBufferedOpacity() {
        #expect(PlayerCinematicVisualPolicy.progressBufferedOpacity == 0.32)
    }

    @Test
    func timeLabelOpacity() {
        #expect(PlayerCinematicVisualPolicy.timeLabelOpacity == 0.74)
    }
}

@Suite("PlayerCinematicVisualPolicy - Scrim Opacity")
struct PlayerCinematicVisualPolicyScrimOpacityTests {

    @Test
    func topScrimOpacity() {
        #expect(PlayerCinematicVisualPolicy.topScrimOpacity == 0.34)
    }

    @Test
    func bottomScrimOpacity() {
        #expect(PlayerCinematicVisualPolicy.bottomScrimOpacity == 0.30)
    }
}
