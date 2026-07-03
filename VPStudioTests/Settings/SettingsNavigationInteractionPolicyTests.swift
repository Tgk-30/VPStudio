import Foundation
import Testing
@testable import VPStudio

@Suite("Settings Navigation Interaction Policy")
struct SettingsNavigationInteractionPolicyTests {
    @Test
    func persistedDestinationMatchesRawValue() {
        for destination in SettingsNavigationCatalog.orderedDestinations {
            let persisted = SettingsNavigationInteractionPolicy.persistedDestinationRawValue(for: destination)
            #expect(persisted == destination.rawValue)
        }
    }

    @Test
    func settingsRootUsesValueNavigationLinksForSingleClickActivation() throws {
        let source = try String(contentsOf: settingsRootURL(), encoding: .utf8)

        #expect(source.contains("NavigationLink(value: destination)"))
        #expect(source.contains(".navigationDestination(for: SettingsDestination.self)"))
        #expect(source.contains(".navigationDestination(item: $selectedDestination)") == false)
        #expect(source.contains("private func openDestination(") == false)
        #expect(source.contains("selectedDestination") == false)
    }

    @Test
    func settingsRootKeepsBottomRowsClearOfVisionWindowChrome() throws {
        let source = try String(contentsOf: settingsRootURL(), encoding: .utf8)
        let containerSource = try String(contentsOf: containersURL(), encoding: .utf8)

        #expect(SettingsRootLayoutPolicy.bottomContentPadding == 320)
        #expect(SettingsRootLayoutPolicy.bottomViewportInset == 260)
        #expect(source.contains("bottomContentPadding: SettingsRootLayoutPolicy.bottomContentPadding"))
        #expect(source.contains("bottomViewportInset: SettingsRootLayoutPolicy.bottomViewportInset"))
        #expect(containerSource.contains("var bottomContentPadding: CGFloat = VPSpace.section"))
        #expect(containerSource.contains("var bottomViewportInset: CGFloat = 0"))
        #expect(containerSource.contains(".safeAreaInset(edge: .bottom)"))
        #expect(containerSource.contains("struct VPBottomViewportScrim: View"))
        #expect(containerSource.contains("VPBottomViewportScrim(height: bottomViewportInset)"))
        #expect(containerSource.contains(".allowsHitTesting(false)"))
    }

    private func settingsRootURL() -> URL {
        repoRootURL().appendingPathComponent("VPStudio/Views/Windows/Settings/Root/SettingsRootView.swift")
    }

    private func containersURL() -> URL {
        repoRootURL().appendingPathComponent("VPStudio/Design/Components/VPContainers.swift")
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
