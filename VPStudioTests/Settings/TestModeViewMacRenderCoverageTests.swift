import SwiftUI
import Testing
@testable import VPStudio

@Suite("Test Mode View Render Coverage")
@MainActor
struct TestModeViewMacRenderCoverageTests {
    @Test
    func launchPolicyResolvesRawValuesAndTitlesAfterNormalization() {
        #expect(TestScreenLaunchPolicy.screen(for: nil) == nil)
        #expect(TestScreenLaunchPolicy.screen(for: "") == nil)
        #expect(TestScreenLaunchPolicy.screen(for: " \n ") == nil)
        #expect(TestScreenLaunchPolicy.screen(for: "unknown") == nil)

        #expect(TestScreenLaunchPolicy.screen(for: "search-results") == .searchResults)
        #expect(TestScreenLaunchPolicy.screen(for: "Search + Results") == .searchResults)
        #expect(TestScreenLaunchPolicy.screen(for: "Movie Detail") == .detailMovie)
        #expect(TestScreenLaunchPolicy.screen(for: "detail_series") == .detailSeries)
        #expect(TestScreenLaunchPolicy.screen(for: "DOWNLOADS") == .downloads)
    }

    @Test
    func screenMetadataKeepsStableOrderAndLabels() {
        #expect(TestScreen.allCases.map(\.id) == [
            "discover",
            "search",
            "searchResults",
            "detailMovie",
            "detailSeries",
            "library",
            "downloads",
            "player",
            "settings",
        ])
        #expect(TestScreen.allCases.allSatisfy { !$0.title.isEmpty })
        #expect(TestScreen.allCases.allSatisfy { !$0.subtitle.isEmpty })
        #expect(TestScreen.allCases.allSatisfy { !$0.icon.isEmpty })
        #expect(Set(TestScreen.allCases.map(\.id)).count == TestScreen.allCases.count)
    }

    #if os(macOS)
    @Test
    func hostsLauncherGridWithAppStateEnvironment() {
        let appState = AppState(testHooks: .init())

        SwiftUIViewDiagnosticHost.render(
            NavigationStack {
                TestModeView()
            }
            .environment(appState),
            width: 720,
            height: 640
        )
    }

    @Test
    func hostsEveryPreviewSheetWithoutSelectionSideEffects() {
        for screen in TestScreen.allCases {
            SwiftUIViewDiagnosticHost.render(
                TestScreenSheet(screen: screen)
                    .frame(width: 700, height: 620),
                width: 700,
                height: 620
            )
        }
    }
    #endif
}
