import Foundation
import Testing
@testable import VPStudio

@Suite("Root Navigation Contract")
struct RootNavigationContractTests {
    @Test
    func rootNavigationStackUsesAnExplicitPath() throws {
        let source = try contentViewSource()

        #expect(source.contains("@State private var rootNavigationPath = NavigationPath()"))
        #expect(source.contains("NavigationStack(path: $rootNavigationPath)"))
    }

    @Test
    func selectedTabChangesClearStalePushedState() throws {
        let source = try contentViewSource()

        let onChangeRange = try requiredRange(
            of: ".onChange(of: state.selectedTab) { previous, next in",
            in: source
        )
        let launchRestoreGuardRange = try requiredRange(
            of: "guard !isRestoringLaunchNavigation else { return }",
            in: source,
            range: onChangeRange.upperBound..<source.endIndex
        )
        let policyRange = try requiredRange(
            of: "RootTabSelectionPolicy.shouldClearNavigationPath(currentTab: previous, selectedTab: next)",
            in: source
        )
        let resetRange = try requiredRange(
            of: "rootNavigationPath = NavigationPath()",
            in: source,
            range: policyRange.upperBound..<source.endIndex
        )

        #expect(onChangeRange.lowerBound < policyRange.lowerBound)
        #expect(onChangeRange.lowerBound < launchRestoreGuardRange.lowerBound)
        #expect(launchRestoreGuardRange.lowerBound < policyRange.lowerBound)
        #expect(policyRange.lowerBound < resetRange.lowerBound)
    }

    @Test
    func quickStartRoutesThroughSelectRootTabAndTheRootSelectionPath() throws {
        let source = try contentViewSource()

        #expect(source.contains("selectRootTab(QuickStartPromptPolicy.skipSetupDestination, state: state)"))
        #expect(source.contains("private func handleTabSelection(_ tab: SidebarTab, state: AppState) {"))
        #expect(source.contains("selectRootTab(tab, state: state)"))
        #expect(source.contains("private func selectRootTab(_ tab: SidebarTab, state: AppState) {"))
        #expect(source.contains("state.selectedTab = tab"))
        #expect(source.contains("if navigationAction == .resetStack {"))
        #expect(!source.contains("if navigationAction == .clearPath {\n            rootNavigationPath = NavigationPath()\n        }\n\n        withAnimation"))
    }

    @Test
    func launchNavigationRestorationCoalescesPersistedAndQaOverrides() throws {
        let source = try contentViewSource()
        let launchBody = try section(
            from: "private func restoreLaunchNavigationState() async {",
            to: "private func refreshRootBadgeCounts() async {",
            in: source
        )

        #expect(source.contains("await restoreLaunchNavigationState()"))
        #expect(source.contains("@State private var isRestoringLaunchNavigation = false"))
        #expect(launchBody.contains("let shouldUpdateTab = launchTab.map { appState.selectedTab != $0 } ?? false"))
        #expect(launchBody.contains("let shouldUpdateLayout = launchLayout.map { appState.navigationLayout != $0 } ?? false"))
        #expect(launchBody.contains("if shouldUpdateTab || shouldUpdateLayout"))
        #expect(launchBody.contains("isRestoringLaunchNavigation = true"))
        #expect(launchBody.contains("let launchTab = QARuntimeOptions.selectedTab ?? savedTab"))
        #expect(launchBody.contains("if let launchTab, shouldUpdateTab"))
        #expect(launchBody.contains("appState.selectedTab = launchTab"))
        #expect(launchBody.contains("let launchLayout = QARuntimeOptions.navigationLayout ?? savedLayout"))
        #expect(launchBody.contains("if let launchLayout, shouldUpdateLayout"))
        #expect(launchBody.contains("appState.navigationLayout = launchLayout"))
        #expect(launchBody.contains("await Task.yield()"))
        #expect(launchBody.contains("isRestoringLaunchNavigation = false"))
        #expect(!launchBody.contains("Task { @MainActor"))
        #expect(!source.contains("appState.selectedTab = qaSelectedTab"))
    }

    @Test
    func qaFullScreenPreviewsHideVisionSystemOverlaysForCleanVisualCapture() throws {
        let source = try contentViewSource()
        let modifierBody = try section(
            from: "#elseif os(visionOS)\nprivate struct QATestScreenPresentationModifier",
            to: "#else\n#error(\"QATestScreenPresentationModifier supports macOS and visionOS only.\")",
            in: source
        )

        #expect(modifierBody.contains(".fullScreenCover(item: $screen)"))
        #expect(modifierBody.contains(".presentationBackground(.clear)"))
        #expect(modifierBody.contains(".persistentSystemOverlays(.hidden)"))
    }

    @Test
    func qaTestScreenPresentationAvoidsRepeatedStateWritesDuringBootstrapRefresh() throws {
        let source = try contentViewSource()
        let presentationBody = try section(
            from: "private func presentQATestScreenIfRequested() {",
            to: "private func restoreLaunchNavigationState() async {",
            in: source
        )

        #expect(source.contains("presentQATestScreenIfRequested()"))
        #expect(presentationBody.contains("if !softSetupPromptDismissed"))
        #expect(presentationBody.contains("if isShowingQuickStartPrompt"))
        #expect(presentationBody.contains("if appState.isShowingSetup"))
        #expect(presentationBody.contains("if appState.isBootstrapping"))
        #expect(presentationBody.contains("if qaPresentedTestScreen != screen"))
        #expect(presentationBody.contains("qaPresentedTestScreen = screen"))
    }

    private func contentViewSource() throws -> String {
        try String(contentsOf: repoRootURL().appendingPathComponent("VPStudio/Views/Windows/ContentView.swift"), encoding: .utf8)
    }

    private func section(from start: String, to end: String, in source: String) throws -> String {
        let startRange = try requiredRange(of: start, in: source)
        let endRange = try requiredRange(of: end, in: source, range: startRange.upperBound..<source.endIndex)
        return String(source[startRange.lowerBound..<endRange.lowerBound])
    }

    private func requiredRange(
        of needle: String,
        in source: String,
        range searchRange: Range<String.Index>? = nil
    ) throws -> Range<String.Index> {
        guard let range = source.range(of: needle, range: searchRange) else {
            Issue.record("Missing expected source text: \(needle)")
            throw NSError(
                domain: "RootNavigationContractTests",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "missing source text"]
            )
        }
        return range
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
