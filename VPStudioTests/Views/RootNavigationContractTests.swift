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
        #expect(policyRange.lowerBound < resetRange.lowerBound)
    }

    @Test
    func quickStartRoutesThroughSelectRootTabAndTheRootSelectionPath() throws {
        let source = try contentViewSource()

        #expect(source.contains("selectRootTab(QuickStartPromptPolicy.skipSetupDestination, state: state)"))
        #expect(source.contains("private func handleTabSelection(_ tab: SidebarTab, state: AppState) {"))
        #expect(source.contains("selectRootTab(tab, state: state)"))
        #expect(source.contains("private func selectRootTab(_ tab: SidebarTab, state: AppState) {"))
        #expect(source.contains("if navigationAction == .clearPath {"))
        #expect(source.contains("state.selectedTab = tab"))
    }

    private func contentViewSource() throws -> String {
        try String(contentsOf: repoRootURL().appendingPathComponent("VPStudio/Views/Windows/ContentView.swift"), encoding: .utf8)
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
