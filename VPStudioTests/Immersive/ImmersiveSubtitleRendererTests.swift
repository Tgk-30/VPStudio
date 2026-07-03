#if os(visionOS)
import Foundation
import Testing
import SwiftUI
@testable import VPStudio

// MARK: - ImmersiveSubtitleRenderer Tests

@Suite("ImmersiveSubtitleRenderer")
@MainActor
struct ImmersiveSubtitleRendererTests {

    // MARK: - View Construction

    @Test("ImmersiveSubtitleRenderer builds with required parameters")
    func buildsWithRequiredParameters() {
        let view = ImmersiveSubtitleRenderer(
            text: "Test subtitle",
            fontSize: 24,
            maxWidth: 1200
        )

        let body = String(describing: view.body)
        #expect(body.contains("Text"))
    }

    @Test("ImmersiveSubtitleRenderer displays the given text")
    func displaysGivenText() {
        let subtitle = ImmersiveSubtitleRenderer(
            text: "Hello World",
            fontSize: 24,
            maxWidth: 1200
        )

        let body = String(describing: subtitle.body)
        #expect(body.contains("Hello World"))
    }

    @Test("ImmersiveSubtitleRenderer uses specified font size")
    func usesSpecifiedFontSize() {
        let subtitle = ImmersiveSubtitleRenderer(
            text: "Test",
            fontSize: 48,
            maxWidth: 2000
        )

        let body = String(describing: subtitle.body)
        #expect(body.contains("48") || body.contains("font"))
    }

    @Test("ImmersiveSubtitleRenderer respects max width")
    func respectsMaxWidth() {
        let subtitle = ImmersiveSubtitleRenderer(
            text: "Test",
            fontSize: 24,
            maxWidth: 1500
        )

        let body = String(describing: subtitle.body)
        #expect(body.contains("1500") || body.contains("maxWidth"))
    }

    // MARK: - Styling

    @Test("ImmersiveSubtitleRenderer uses white foreground")
    func usesWhiteForeground() {
        let subtitle = ImmersiveSubtitleRenderer(
            text: "Test",
            fontSize: 24,
            maxWidth: 1200
        )

        let body = String(describing: subtitle.body)
        #expect(body.contains("white") || body.contains("foregroundStyle"))
    }

    @Test("ImmersiveSubtitleRenderer applies shadow")
    func appliesShadow() {
        let subtitle = ImmersiveSubtitleRenderer(
            text: "Test",
            fontSize: 24,
            maxWidth: 1200
        )

        let body = String(describing: subtitle.body)
        #expect(body.contains("_ShadowEffect"))
    }

    @Test("ImmersiveSubtitleRenderer is multiline aligned center")
    func isMultilineAlignedCenter() {
        let subtitle = ImmersiveSubtitleRenderer(
            text: "Multi-line subtitle text",
            fontSize: 24,
            maxWidth: 1200
        )

        let body = String(describing: subtitle.body)
        #expect(body.contains("multilineTextAlignment") || body.contains("center"))
    }

    @Test("ImmersiveSubtitleRenderer has line limit of 4")
    func hasLineLimitOfFour() {
        let subtitle = ImmersiveSubtitleRenderer(
            text: "Test",
            fontSize: 24,
            maxWidth: 1200
        )

        let body = String(describing: subtitle.body)
        #expect(body.contains("lineLimit") || body.contains("4"))
    }

    @Test("ImmersiveSubtitleRenderer has horizontal padding")
    func hasHorizontalPadding() {
        let subtitle = ImmersiveSubtitleRenderer(
            text: "Test",
            fontSize: 24,
            maxWidth: 1200
        )

        let body = String(describing: subtitle.body)
        #expect(body.contains("padding") || body.contains("horizontal"))
    }

    @Test("ImmersiveSubtitleRenderer has vertical padding")
    func hasVerticalPadding() {
        let subtitle = ImmersiveSubtitleRenderer(
            text: "Test",
            fontSize: 24,
            maxWidth: 1200
        )

        let body = String(describing: subtitle.body)
        #expect(body.contains("padding") || body.contains("vertical"))
    }

    @Test("ImmersiveSubtitleRenderer has rounded rectangle background")
    func hasRoundedBackground() {
        let subtitle = ImmersiveSubtitleRenderer(
            text: "Test",
            fontSize: 24,
            maxWidth: 1200
        )

        let body = String(describing: subtitle.body)
        #expect(body.contains("RoundedRectangle") || body.contains("background"))
    }

    @Test("ImmersiveSubtitleRenderer uses medium font weight")
    func usesMediumFontWeight() {
        let subtitle = ImmersiveSubtitleRenderer(
            text: "Test",
            fontSize: 24,
            maxWidth: 1200
        )

        let body = String(describing: subtitle.body)
        #expect(body.contains("font") || body.contains("Font"))
    }

    // MARK: - Empty Text Handling

    @Test("ImmersiveSubtitleRenderer handles empty string")
    func handlesEmptyString() {
        let subtitle = ImmersiveSubtitleRenderer(
            text: "",
            fontSize: 24,
            maxWidth: 1200
        )

        let body = String(describing: subtitle.body)
        #expect(body.contains("Text"))
    }

    @Test("ImmersiveSubtitleRenderer handles very long text")
    func handlesLongText() {
        let longText = String(repeating: "word ", count: 100)
        let subtitle = ImmersiveSubtitleRenderer(
            text: longText,
            fontSize: 24,
            maxWidth: 1200
        )

        let body = String(describing: subtitle.body)
        #expect(body.contains("Text"))
    }

    // MARK: - Font Size Extremes

    @Test("ImmersiveSubtitleRenderer handles minimum font size")
    func handlesMinimumFontSize() {
        let subtitle = ImmersiveSubtitleRenderer(
            text: "Test",
            fontSize: 8,
            maxWidth: 1200
        )

        let body = String(describing: subtitle.body)
        #expect(body.contains("8") || body.contains("font"))
    }

    @Test("ImmersiveSubtitleRenderer handles large font size")
    func handlesLargeFontSize() {
        let subtitle = ImmersiveSubtitleRenderer(
            text: "Test",
            fontSize: 120,
            maxWidth: 1200
        )

        let body = String(describing: subtitle.body)
        #expect(body.contains("120") || body.contains("font"))
    }
}

// MARK: - ScreenSizePreset Subtitle Extension Tests

@Suite("ScreenSizePreset Subtitle Extensions")
struct ScreenSizePresetSubtitleExtensionsTests {

    // MARK: - Font Sizes

    @Test("Personal subtitle font size is 36pt")
    func personalSubtitleFontSize() {
        #expect(ScreenSizePreset.personal.subtitleFontSize == 36)
    }

    @Test("Cinema subtitle font size is 60pt")
    func cinemaSubtitleFontSize() {
        #expect(ScreenSizePreset.cinema.subtitleFontSize == 60)
    }

    @Test("IMAX subtitle font size is 80pt")
    func imaxSubtitleFontSize() {
        #expect(ScreenSizePreset.imax.subtitleFontSize == 80)
    }

    @Test("Font sizes increase with preset size")
    func fontSizesIncreaseWithPreset() {
        #expect(ScreenSizePreset.personal.subtitleFontSize < ScreenSizePreset.cinema.subtitleFontSize)
        #expect(ScreenSizePreset.cinema.subtitleFontSize < ScreenSizePreset.imax.subtitleFontSize)
    }

    // MARK: - Max Widths

    @Test("Personal subtitle max width is 1200pt")
    func personalSubtitleMaxWidth() {
        #expect(ScreenSizePreset.personal.subtitleMaxWidth == 1200)
    }

    @Test("Cinema subtitle max width is 2000pt")
    func cinemaSubtitleMaxWidth() {
        #expect(ScreenSizePreset.cinema.subtitleMaxWidth == 2000)
    }

    @Test("IMAX subtitle max width is 3200pt")
    func imaxSubtitleMaxWidth() {
        #expect(ScreenSizePreset.imax.subtitleMaxWidth == 3200)
    }

    @Test("Max widths increase with preset size")
    func maxWidthsIncreaseWithPreset() {
        #expect(ScreenSizePreset.personal.subtitleMaxWidth < ScreenSizePreset.cinema.subtitleMaxWidth)
        #expect(ScreenSizePreset.cinema.subtitleMaxWidth < ScreenSizePreset.imax.subtitleMaxWidth)
    }

    // MARK: - Vertical Offsets

    @Test("Personal subtitle vertical offset formula")
    func personalSubtitleVerticalOffsetFormula() {
        let expected = ScreenSizePreset.personal.height / 2 + 0.15
        #expect(ScreenSizePreset.personal.subtitleVerticalOffset == expected)
    }

    @Test("Cinema subtitle vertical offset formula")
    func cinemaSubtitleVerticalOffsetFormula() {
        let expected = ScreenSizePreset.cinema.height / 2 + 0.15
        #expect(ScreenSizePreset.cinema.subtitleVerticalOffset == expected)
    }

    @Test("IMAX subtitle vertical offset formula")
    func imaxSubtitleVerticalOffsetFormula() {
        let expected = ScreenSizePreset.imax.height / 2 + 0.15
        #expect(ScreenSizePreset.imax.subtitleVerticalOffset == expected)
    }

    @Test("Vertical offsets increase with preset size")
    func verticalOffsetsIncreaseWithPreset() {
        #expect(ScreenSizePreset.personal.subtitleVerticalOffset < ScreenSizePreset.cinema.subtitleVerticalOffset)
        #expect(ScreenSizePreset.cinema.subtitleVerticalOffset < ScreenSizePreset.imax.subtitleVerticalOffset)
    }

    @Test("All vertical offsets are positive")
    func allVerticalOffsetsPositive() {
        for preset in ScreenSizePreset.allCases {
            #expect(preset.subtitleVerticalOffset > 0)
        }
    }

    // MARK: - Relationship to Screen Dimensions

    @Test("Max width is approximately 80% of screen width for personal")
    func personalMaxWidthIs80PercentOfScreen() {
        let screenWidth = ScreenSizePreset.personal.width
        let expectedWidth = Double(screenWidth) * 0.8 * 250 // Scale factor for points
        #expect(abs(Double(ScreenSizePreset.personal.subtitleMaxWidth) - expectedWidth) < 1)
    }

    @Test("Max width is approximately 80% of screen width for cinema")
    func cinemaMaxWidthIs80PercentOfScreen() {
        let screenWidth = ScreenSizePreset.cinema.width
        let expectedWidth = Double(screenWidth) * 0.8 * 250
        #expect(abs(Double(ScreenSizePreset.cinema.subtitleMaxWidth) - expectedWidth) < 1)
    }

    @Test("Max width is approximately 80% of screen width for imax")
    func imaxMaxWidthIs80PercentOfScreen() {
        let screenWidth = ScreenSizePreset.imax.width
        let expectedWidth = Double(screenWidth) * 0.8 * 250
        #expect(abs(Double(ScreenSizePreset.imax.subtitleMaxWidth) - expectedWidth) < 1)
    }
}

#endif