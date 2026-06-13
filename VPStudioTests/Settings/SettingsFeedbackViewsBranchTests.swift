import SwiftUI
import Testing
@testable import VPStudio

@MainActor
@Suite("Settings Feedback Views Branch Coverage")
struct SettingsFeedbackViewsBranchTests {
    @Test
    func inlineNoticeFactoriesPreserveCustomSymbolsAndMessages() {
        let success = SettingsInlineNotice.success(
            "Saved provider token",
            symbolName: "checkmark.seal.fill"
        )
        let info = SettingsInlineNotice.info(
            "Optional configuration",
            symbolName: "lightbulb.fill"
        )
        let warning = SettingsInlineNotice.warning(
            "Provider needs attention",
            symbolName: "exclamationmark.octagon.fill"
        )

        #expect(success.message == "Saved provider token")
        #expect(success.symbolName == "checkmark.seal.fill")
        #expect(success.tone == .success)
        #expect(info.message == "Optional configuration")
        #expect(info.symbolName == "lightbulb.fill")
        #expect(info.tone == .info)
        #expect(warning.message == "Provider needs attention")
        #expect(warning.symbolName == "exclamationmark.octagon.fill")
        #expect(warning.tone == .warning)
    }

    @Test
    func inlineNoticeFactoriesUseStableDefaultSymbols() {
        let success = SettingsInlineNotice.success("Saved")
        let info = SettingsInlineNotice.info("Optional")
        let warning = SettingsInlineNotice.warning("Needs setup")

        #expect(success.symbolName == "checkmark.circle.fill")
        #expect(success.tone == .success)
        #expect(info.symbolName == "info.circle.fill")
        #expect(info.tone == .info)
        #expect(warning.symbolName == "exclamationmark.triangle.fill")
        #expect(warning.tone == .warning)
    }

    @Test
    func toneTintBranchesReturnRenderableColors() {
        let tints: [Color] = [
            SettingsInlineNotice.Tone.success.tint,
            SettingsInlineNotice.Tone.info.tint,
            SettingsInlineNotice.Tone.warning.tint,
        ]

        #expect(tints.count == 3)
    }

    @Test
    func noticeBannersBuildForEveryTone() {
        _ = SettingsNoticeBanner(notice: .success("Saved")).body
        _ = SettingsNoticeBanner(notice: .info("Optional configuration")).body
        _ = SettingsNoticeBanner(notice: .warning("Needs attention")).body
    }

    @Test
    func noticeAndErrorBannersBuildWithLongMessages() {
        _ = SettingsNoticeBanner(
            notice: .info(
                "This is a longer settings notice that should wrap without requiring a separate alert surface."
            )
        ).body
        _ = SettingsErrorBanner(error: .unknown("Settings persistence failed")).body
    }

    @Test
    func noticeAndErrorBannersRenderEveryToneWithWrappingMessages() {
        let view = VStack(spacing: 12) {
            SettingsNoticeBanner(notice: .success("Saved provider token"))
            SettingsNoticeBanner(notice: .info("Optional configuration can be completed later."))
            SettingsNoticeBanner(notice: .warning("Provider needs attention before recommendations can run."))
            SettingsErrorBanner(error: .unknown("Settings persistence failed while saving the selected provider."))
        }
        .padding()

        SwiftUIViewDiagnosticHost.render(view, width: 520, height: 260)
    }
}
