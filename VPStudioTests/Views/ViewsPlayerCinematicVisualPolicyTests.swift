import Testing
@testable import VPStudio

@Suite("PlayerCinematicVisualPolicy Constants")
struct PlayerCinematicVisualPolicyTestsViewsViewsplayercinematicvisualpolicytests {
    @Test("Back symbol name")
    func backSymbolName() {
        #expect(PlayerCinematicVisualPolicy.backSymbolName == "chevron.left")
    }

    @Test("Menu symbol name")
    func menuSymbolName() {
        #expect(PlayerCinematicVisualPolicy.menuSymbolName == "ellipsis")
    }

    @Test("Subtitles symbol name")
    func subtitlesSymbolName() {
        #expect(PlayerCinematicVisualPolicy.subtitlesSymbolName == "captions.bubble.fill")
    }

    @Test("Audio symbol name")
    func audioSymbolName() {
        #expect(PlayerCinematicVisualPolicy.audioSymbolName == "speaker.wave.2.fill")
    }

    @Test("Quality symbol name")
    func qualitySymbolName() {
        #expect(PlayerCinematicVisualPolicy.qualitySymbolName == "line.3.horizontal.decrease.circle.fill")
    }

    @Test("Stream list symbol name")
    func streamListSymbolName() {
        #expect(PlayerCinematicVisualPolicy.streamListSymbolName == "rectangle.stack.badge.play.fill")
    }

    @Test("Previous chapter symbol name")
    func previousChapterSymbolName() {
        #expect(PlayerCinematicVisualPolicy.previousChapterSymbolName == "backward.end.fill")
    }

    @Test("Next chapter symbol name")
    func nextChapterSymbolName() {
        #expect(PlayerCinematicVisualPolicy.nextChapterSymbolName == "forward.end.fill")
    }

    @Test("Skip back symbol name")
    func skipBackSymbolName() {
        #expect(PlayerCinematicVisualPolicy.skipBackSymbolName == "gobackward.10")
    }

    @Test("Skip forward symbol name")
    func skipForwardSymbolName() {
        #expect(PlayerCinematicVisualPolicy.skipForwardSymbolName == "goforward.10")
    }

    @Test("Icon surface border opacity")
    func iconSurfaceBorderOpacity() {
        #expect(PlayerCinematicVisualPolicy.iconSurfaceBorderOpacity == 0.30)
    }

    @Test("Icon surface highlight opacity")
    func iconSurfaceHighlightOpacity() {
        #expect(PlayerCinematicVisualPolicy.iconSurfaceHighlightOpacity == 0.22)
    }

    @Test("Icon surface shadow opacity")
    func iconSurfaceShadowOpacity() {
        #expect(PlayerCinematicVisualPolicy.iconSurfaceShadowOpacity == 0.44)
    }

    @Test("Active control border opacity")
    func activeControlBorderOpacity() {
        #expect(PlayerCinematicVisualPolicy.activeControlBorderOpacity == 0.88)
    }

    @Test("Progress track opacity")
    func progressTrackOpacity() {
        #expect(PlayerCinematicVisualPolicy.progressTrackOpacity == 0.18)
    }

    @Test("Progress buffered opacity")
    func progressBufferedOpacity() {
        #expect(PlayerCinematicVisualPolicy.progressBufferedOpacity == 0.32)
    }

    @Test("Time label opacity")
    func timeLabelOpacity() {
        #expect(PlayerCinematicVisualPolicy.timeLabelOpacity == 0.74)
    }

    @Test("Top scrim opacity")
    func topScrimOpacity() {
        #expect(PlayerCinematicVisualPolicy.topScrimOpacity == 0.34)
    }

    @Test("Bottom scrim opacity")
    func bottomScrimOpacity() {
        #expect(PlayerCinematicVisualPolicy.bottomScrimOpacity == 0.30)
    }

    @Test("All opacities are within valid range")
    func opacityRange() {
        let allOpacities = [
            PlayerCinematicVisualPolicy.iconSurfaceBorderOpacity,
            PlayerCinematicVisualPolicy.iconSurfaceHighlightOpacity,
            PlayerCinematicVisualPolicy.iconSurfaceShadowOpacity,
            PlayerCinematicVisualPolicy.activeControlBorderOpacity,
            PlayerCinematicVisualPolicy.progressTrackOpacity,
            PlayerCinematicVisualPolicy.progressBufferedOpacity,
            PlayerCinematicVisualPolicy.timeLabelOpacity,
            PlayerCinematicVisualPolicy.topScrimOpacity,
            PlayerCinematicVisualPolicy.bottomScrimOpacity
        ]
        for opacity in allOpacities {
            #expect(opacity >= 0 && opacity <= 1, "Opacity \(opacity) should be between 0 and 1")
        }
    }

    @Test("Symbol names are non-empty")
    func symbolNamesNonEmpty() {
        #expect(!PlayerCinematicVisualPolicy.backSymbolName.isEmpty)
        #expect(!PlayerCinematicVisualPolicy.menuSymbolName.isEmpty)
        #expect(!PlayerCinematicVisualPolicy.subtitlesSymbolName.isEmpty)
        #expect(!PlayerCinematicVisualPolicy.audioSymbolName.isEmpty)
        #expect(!PlayerCinematicVisualPolicy.qualitySymbolName.isEmpty)
        #expect(!PlayerCinematicVisualPolicy.streamListSymbolName.isEmpty)
        #expect(!PlayerCinematicVisualPolicy.previousChapterSymbolName.isEmpty)
        #expect(!PlayerCinematicVisualPolicy.nextChapterSymbolName.isEmpty)
        #expect(!PlayerCinematicVisualPolicy.skipBackSymbolName.isEmpty)
        #expect(!PlayerCinematicVisualPolicy.skipForwardSymbolName.isEmpty)
    }
}
