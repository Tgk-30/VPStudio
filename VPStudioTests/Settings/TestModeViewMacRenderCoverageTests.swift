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
        #expect(TestScreenLaunchPolicy.screen(for: "environment-picker") == .environmentPicker)
        #expect(TestScreenLaunchPolicy.screen(for: "Environment Settings") == .environmentSettings)
        #expect(TestScreenLaunchPolicy.screen(for: "Metadata Settings") == .metadataSettings)
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
            "environmentsTab",
            "environmentPicker",
            "environmentSettings",
            "player",
            "settings",
            "metadataSettings",
            "setupPreferences",
        ])
        #expect(TestScreen.allCases.allSatisfy { !$0.title.isEmpty })
        #expect(TestScreen.allCases.allSatisfy { !$0.subtitle.isEmpty })
        #expect(TestScreen.allCases.allSatisfy { !$0.icon.isEmpty })
        #expect(Set(TestScreen.allCases.map(\.id)).count == TestScreen.allCases.count)
    }

    @Test
    func seededDetailPreviewCanOpenRealPlayerForQASamplePlayback() throws {
        let source = try testModeViewSource()

        #expect(source.contains("@Environment(\\.openWindow) private var openWindow"))
        #expect(source.contains("@State private var didOpenQASamplePlayer = false"))
        #expect(source.contains("openQASamplePlayerIfRequested(viewModel)"))
        #expect(source.contains("guard QARuntimeOptions.autoPlaySample, !didOpenQASamplePlayer else { return }"))
        #expect(source.contains("DetailQASamplePolicy.makeSampleStreams("))
        #expect(source.contains("QARuntimeOptions.playerAppleEnvironmentMode"))
        #expect(source.contains("@State private var appleEnvironmentClearTask: Task<Void, Never>?"))
        #expect(source.contains("await appState.clearEnvironmentSelection()"))
        let clearRange = try #require(source.range(of: "await appState.clearEnvironmentSelection()"))
        let openRange = try #require(source.range(of: "openWindow(id: \"player\", value: request)"))
        #expect(clearRange.lowerBound < openRange.lowerBound)
        #expect(source.contains("appState.beginEmbeddedPlayerSession(request)"))
        #expect(source.contains("openWindow(id: \"player\", value: request)"))
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

    private func testModeViewSource() throws -> String {
        try String(contentsOf: repoRootURL().appendingPathComponent("VPStudio/Views/Windows/Settings/Destinations/TestModeView.swift"), encoding: .utf8)
    }

    private func repoRootURL() -> URL {
        var url = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
        while !FileManager.default.fileExists(atPath: url.appendingPathComponent("Package.swift").path) {
            let parent = url.deletingLastPathComponent()
            if parent.path == url.path { break }
            url = parent
        }
        return url
    }
}
