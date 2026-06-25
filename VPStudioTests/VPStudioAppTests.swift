import Foundation
import Testing
@testable import VPStudio

@Suite(.serialized)
struct VPStudioAppTests {

    private static func contents(of relativePath: String) throws -> String {
        let repoRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let fileURL = repoRoot.appendingPathComponent(relativePath)
        return try String(contentsOf: fileURL, encoding: .utf8)
    }

    // MARK: - App Delegate macOS

    @Test
    func macOSAppDelegatePreventsTerminationOnLastWindowClose() throws {
        #if os(macOS)
        let source = try Self.contents(of: "VPStudio/App/VPStudioApp.swift")
        #expect(source.contains("applicationShouldTerminateAfterLastWindowClosed"))
        #expect(source.contains("-> Bool"))
        #expect(source.contains("false"))
        #else
        #expect(Bool(true), "macOS-only test — skipped on this platform")
        #endif
    }

    // MARK: - Scene Configuration

    @Test
    func mainWindowGroupHasCorrectID() throws {
        let source = try Self.contents(of: "VPStudio/App/VPStudioApp.swift")
        #expect(source.contains("WindowGroup(id: \"main\")"))
    }

    @Test
    func mainWindowGroupUses1200x800DefaultSize() throws {
        let source = try Self.contents(of: "VPStudio/App/VPStudioApp.swift")
        #expect(source.contains(".defaultSize(width: 1200, height: 800)"))
    }

    @Test
    func mainWindowGroupInjectsAppStateEnvironment() throws {
        let source = try Self.contents(of: "VPStudio/App/VPStudioApp.swift")
        #expect(source.contains(".environment(appState)"))
    }

    @Test
    func playerWindowGroupHasCorrectID() throws {
        let source = try Self.contents(of: "VPStudio/App/VPStudioApp.swift")
        #expect(source.contains("WindowGroup(id: \"player\", for: PlayerSessionRequest.self)"))
    }

    @Test
    func playerWindowGroupUses1400x788DefaultSize() throws {
        let source = try Self.contents(of: "VPStudio/App/VPStudioApp.swift")
        #expect(source.contains(".defaultSize(width: 1400, height: 788)"))
    }

    @Test
    func playerWindowGroupInjectsAppStateEnvironment() throws {
        let source = try Self.contents(of: "VPStudio/App/VPStudioApp.swift")
        #expect(source.contains("PlayerView("))
        #expect(source.contains(".environment(appState)"))
    }

    @Test
    func playerWindowGroupPassesSessionRequestForValueBackedDismissal() throws {
        let source = try Self.contents(of: "VPStudio/App/VPStudioApp.swift")
        #expect(source.contains("WindowGroup(id: \"player\", for: PlayerSessionRequest.self)"))
        #expect(source.contains("sessionRequest: resolved"))
    }

    @Test
    func playerWindowGroupInjectsSharedEngine() throws {
        let source = try Self.contents(of: "VPStudio/App/VPStudioApp.swift")
        #expect(source.contains(".environment(sharedEngine)"))
    }

    // MARK: - visionOS Immersive Spaces

    @Test
    func hdriSkyboxImmersiveSpaceHasCorrectID() throws {
        #if os(visionOS)
        let source = try Self.contents(of: "VPStudio/App/VPStudioApp.swift")
        #expect(source.contains("ImmersiveSpace(id: \"hdriSkybox\")"))
        #expect(source.contains(".immersionStyle(selection: $hdriImmersionStyle, in: .full)"))
        #else
        #expect(Bool(true), "visionOS-only test — skipped on this platform")
        #endif
    }

    @Test
    func hdriSkyboxSpaceInjectsAppStateAndEngine() throws {
        #if os(visionOS)
        let source = try Self.contents(of: "VPStudio/App/VPStudioApp.swift")
        #expect(source.contains("HDRISkyboxEnvironment()"))
        #expect(source.contains(".environment(appState)"))
        #expect(source.contains(".environment(sharedEngine)"))
        #else
        #expect(Bool(true), "visionOS-only test — skipped on this platform")
        #endif
    }

    @Test
    func customEnvironmentSpaceHasCorrectID() throws {
        #if os(visionOS)
        let source = try Self.contents(of: "VPStudio/App/VPStudioApp.swift")
        #expect(source.contains("ImmersiveSpace(id: \"customEnvironment\")"))
        #expect(source.contains(".immersionStyle(selection: $customEnvImmersionStyle, in: .full)"))
        #else
        #expect(Bool(true), "visionOS-only test — skipped on this platform")
        #endif
    }

    @Test
    func customEnvironmentSpaceInjectsAppStateAndEngine() throws {
        #if os(visionOS)
        let source = try Self.contents(of: "VPStudio/App/VPStudioApp.swift")
        #expect(source.contains("CustomEnvironmentView()"))
        #expect(source.contains(".environment(appState)"))
        #expect(source.contains(".environment(sharedEngine)"))
        #else
        #expect(Bool(true), "visionOS-only test — skipped on this platform")
        #endif
    }

    @Test
    func cinemaEnvironmentSpaceHasCorrectID() throws {
        #if os(visionOS)
        let source = try Self.contents(of: "VPStudio/App/VPStudioApp.swift")
        #expect(source.contains("ImmersiveSpace(id: \"cinemaEnvironment\")"))
        #expect(source.contains(".immersionStyle(selection: $cinemaImmersionStyle, in: .full)"))
        #else
        #expect(Bool(true), "visionOS-only test — skipped on this platform")
        #endif
    }

    @Test
    func cinemaEnvironmentSpaceInjectsAppStateAndEngine() throws {
        #if os(visionOS)
        let source = try Self.contents(of: "VPStudio/App/VPStudioApp.swift")
        #expect(source.contains("CinemaImmersiveContent(settings: cinemaSettings)"))
        #expect(source.contains(".environment(appState)"))
        #expect(source.contains(".environment(sharedEngine)"))
        #else
        #expect(Bool(true), "visionOS-only test — skipped on this platform")
        #endif
    }

    @Test
    func allImmersiveSpacesUseFullUpperLimbVisibility() throws {
        #if os(visionOS)
        let source = try Self.contents(of: "VPStudio/App/VPStudioApp.swift")
        #expect(source.contains(".upperLimbVisibility(.visible)"))
        #else
        #expect(Bool(true), "visionOS-only test — skipped on this platform")
        #endif
    }

    // MARK: - Audio Session Configuration

    @Test
    func audioSessionConfiguredForPlaybackOnNonMacOS() throws {
        #if !os(macOS)
        let source = try Self.contents(of: "VPStudio/App/VPStudioApp.swift")
        let configurator = try Self.contents(of: "VPStudio/Services/Player/Audio/AudioSessionConfigurator.swift")
        #expect(source.contains("AudioSessionConfigurator.configurePlaybackAsync(policy: .longFormVideo)"))
        #expect(configurator.contains("AVAudioSession.sharedInstance()"))
        #expect(configurator.contains(".playback"))
        #expect(configurator.contains(".moviePlayback"))
        #expect(configurator.contains(".longFormVideo"))
        #else
        #expect(Bool(true), "non-macOS test — skipped on this platform")
        #endif
    }

    @Test
    func audioSessionActivationIsNonblockingOnInit() throws {
        #if !os(macOS)
        let configurator = try Self.contents(of: "VPStudio/Services/Player/Audio/AudioSessionConfigurator.swift")
        #expect(configurator.contains("Task.detached(priority: .userInitiated)"))
        #expect(configurator.contains("try session.setActive(true)"))
        #else
        #expect(Bool(true), "non-macOS test — skipped on this platform")
        #endif
    }

    @Test
    func audioSessionConfiguresMultichannelSupportOniOS15Plus() throws {
        #if !os(macOS)
        let configurator = try Self.contents(of: "VPStudio/Services/Player/Audio/AudioSessionConfigurator.swift")
        #expect(configurator.contains("setSupportsMultichannelContent(true)"))
        #expect(configurator.contains("#available(iOS 15.0"))
        #else
        #expect(Bool(true), "non-macOS test — skipped on this platform")
        #endif
    }

    @Test
    func audioSessionConfigErrorsAreLoggedNotThrown() throws {
        #if !os(macOS)
        let source = try Self.contents(of: "VPStudio/Services/Player/Audio/AudioSessionConfigurator.swift")
        #expect(source.contains("logger.error("))
        #expect(source.contains("Failed to configure AVAudioSession"))
        #else
        #expect(Bool(true), "non-macOS test — skipped on this platform")
        #endif
    }

    @Test
    func audioSessionNotConfiguredOnMacOS() throws {
        #if os(macOS)
        let source = try Self.contents(of: "VPStudio/App/VPStudioApp.swift")
        let nonMacosSectionsRemoved = source.replacingOccurrences(
            of: #"#if !os\(macOS\)[\s\S]*?#endif"#,
            with: "",
            options: .regularExpression
        )
        #expect(!nonMacosSectionsRemoved.contains("AVAudioSession"))
        #else
        #expect(Bool(true), "macOS-only test — skipped on this platform")
        #endif
    }

    // MARK: - macOS Specific

    @Test
    func macOSUsesPlainWindowStyleForPlayer() throws {
        #if os(macOS)
        let source = try Self.contents(of: "VPStudio/App/VPStudioApp.swift")
        #expect(source.contains(".windowStyle(.plain)"))
        #else
        #expect(Bool(true), "macOS-only test — skipped on this platform")
        #endif
    }

    @Test
    func macOSPlayerWindowHasContentMinSizeResizability() throws {
        #if os(macOS)
        let source = try Self.contents(of: "VPStudio/App/VPStudioApp.swift")
        #expect(source.contains(".windowResizability(.contentMinSize)"))
        #else
        #expect(Bool(true), "macOS-only test — skipped on this platform")
        #endif
    }

    // MARK: - visionOS Specific

    @Test
    func visionOSUsesAutomaticWindowResizabilityForPlayer() throws {
        #if os(visionOS)
        let source = try Self.contents(of: "VPStudio/App/VPStudioApp.swift")
        #expect(source.contains(".windowResizability(.automatic)"))
        #else
        #expect(Bool(true), "visionOS-only test — skipped on this platform")
        #endif
    }

    @Test
    func visionOSPlayerViewUsesCinemaSettings() throws {
        #if os(visionOS)
        let source = try Self.contents(of: "VPStudio/App/VPStudioApp.swift")
        #expect(source.contains(".environment(cinemaSettings)"))
        #else
        #expect(Bool(true), "visionOS-only test — skipped on this platform")
        #endif
    }

    // MARK: - App State Initialization

    @Test
    func appStateIsCreatedAsState() throws {
        let source = try Self.contents(of: "VPStudio/App/VPStudioApp.swift")
        #expect(source.contains("@State private var appState = AppState()"))
    }

    @Test
    func sharedEngineIsCreatedAsState() throws {
        let source = try Self.contents(of: "VPStudio/App/VPStudioApp.swift")
        #expect(source.contains("@State private var sharedEngine = VPPlayerEngine()"))
    }

    // MARK: - ContentView Integration

    @Test
    func mainWindowGroupUsesContentView() throws {
        let source = try Self.contents(of: "VPStudio/App/VPStudioApp.swift")
        #expect(source.contains("ContentView()"))
    }

    // MARK: - @main Attribute

    @Test
    func structIsMarkedAsMainEntryPoint() throws {
        let source = try Self.contents(of: "VPStudio/App/VPStudioApp.swift")
        #expect(source.contains("@main"))
    }

    @Test
    func structConformsToAppProtocol() throws {
        let source = try Self.contents(of: "VPStudio/App/VPStudioApp.swift")
        #expect(source.contains("struct VPStudioApp: App {"))
    }

    // MARK: - NavigationLayout

    @Test
    func navigationLayoutHasBottomTabBarAndLeftSidebarCases() throws {
        #expect(NavigationLayout.allCases.count == 2)
        #expect(NavigationLayout.bottomTabBar.rawValue == "bottom")
        #expect(NavigationLayout.leftSidebar.rawValue == "sidebar")
    }

    @Test
    func navigationLayoutDisplayNames() throws {
        #expect(NavigationLayout.bottomTabBar.displayName == "Bottom Tab Bar")
        #expect(NavigationLayout.leftSidebar.displayName == "Left Sidebar")
    }

    // MARK: - SidebarTab Main Tabs

    @Test
    func sidebarTabMainTabsExcludesSettings() throws {
        #expect(SidebarTab.mainTabs.contains(.settings) == false)
        #expect(SidebarTab.mainTabs.count == 5)
    }

    @Test
    func sidebarTabMainTabsContainsCorrectTabs() throws {
        #expect(SidebarTab.mainTabs.contains(.discover))
        #expect(SidebarTab.mainTabs.contains(.search))
        #expect(SidebarTab.mainTabs.contains(.library))
        #expect(SidebarTab.mainTabs.contains(.downloads))
        #expect(SidebarTab.mainTabs.contains(.environments))
    }
}
