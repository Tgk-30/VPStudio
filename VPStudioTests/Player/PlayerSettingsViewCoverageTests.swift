import Foundation
import SwiftUI
import Testing
@testable import VPStudio

@Suite("PlayerSettingsView Coverage")
@MainActor
struct PlayerSettingsViewCoverageTests {
    private static func waitUntil(
        timeout: Duration = .seconds(2),
        condition: @MainActor () -> Bool
    ) async throws {
        let deadline = ContinuousClock.now + timeout
        while !condition() {
            guard ContinuousClock.now < deadline else {
                Issue.record("waitUntil timed out after \(timeout)")
                return
            }
            await Task.yield()
            try await Task.sleep(for: .milliseconds(20))
        }
    }

    @Test func loadSettingsUpdatesAppStateFromStoredPreferences() async throws {
        let appState = try await makeAppState(
            preferredQuality: VideoQuality.uhd4k.rawValue,
            autoPlay: false,
            hardwareDecoding: false,
            playerEngineStrategy: PlayerEngineStrategy.performance.rawValue,
            externalPlayerApp: ExternalPlayerApp.custom.rawValue,
            externalPlayerTemplate: "  player://open?url={raw_url}  ",
            preferCached: false,
            preferAtmos: false,
            hdrPreference: HDRPreference.dolbyVision.rawValue,
            runtimeDiagnosticsEnabled: true,
            navigationLayout: NavigationLayout.leftSidebar.rawValue
        )

        SwiftUIViewDiagnosticHost.render(
            PlayerSettingsView()
                .environment(appState)
        )

        try await Self.waitUntil {
            appState.runtimeDiagnosticsEnabled == true && appState.navigationLayout == .leftSidebar
        }

        #expect(appState.runtimeDiagnosticsEnabled == true)
        #expect(appState.navigationLayout == .leftSidebar)
    }

    @Test func customPlayerTemplateSectionRendersEmptyValidAndInvalidStates() async throws {
        let appState = AppState(settingsManager: SettingsManager(database: try await makeDatabase(), secretStore: TestSecretStore()))

        SwiftUIViewDiagnosticHost.render(
            PlayerSettingsView(
                initialExternalPlayerApp: .custom,
                initialExternalPlayerTemplate: "",
                disablesAutomaticTasks: true
            )
            .environment(appState)
        )

        SwiftUIViewDiagnosticHost.render(
            PlayerSettingsView(
                initialExternalPlayerApp: .custom,
                initialExternalPlayerTemplate: "player://open?url={url}",
                disablesAutomaticTasks: true
            )
            .environment(appState)
        )

        SwiftUIViewDiagnosticHost.render(
            PlayerSettingsView(
                initialExternalPlayerApp: .custom,
                initialExternalPlayerTemplate: "{foo}",
                initialSurfaceError: .unknown("Playback settings could not be saved."),
                disablesAutomaticTasks: true
            )
            .environment(appState)
        )

        #expect(appState.runtimeDiagnosticsEnabled == false)
        #expect(appState.navigationLayout == .bottomTabBar)
    }

    private func makeAppState(
        preferredQuality: String,
        autoPlay: Bool,
        hardwareDecoding: Bool,
        playerEngineStrategy: String,
        externalPlayerApp: String,
        externalPlayerTemplate: String,
        preferCached: Bool,
        preferAtmos: Bool,
        hdrPreference: String,
        runtimeDiagnosticsEnabled: Bool,
        navigationLayout: String
    ) async throws -> AppState {
        let database = try await makeDatabase()
        let secretStore = TestSecretStore()
        let settingsManager = SettingsManager(database: database, secretStore: secretStore)

        try await settingsManager.setString(key: SettingsKeys.preferredQuality, value: preferredQuality)
        try await settingsManager.setBool(key: SettingsKeys.autoPlayNext, value: autoPlay)
        try await settingsManager.setBool(key: SettingsKeys.hardwareDecoding, value: hardwareDecoding)
        try await settingsManager.setString(key: SettingsKeys.playerEngineStrategy, value: playerEngineStrategy)
        try await settingsManager.setString(key: SettingsKeys.externalPlayerApp, value: externalPlayerApp)
        try await settingsManager.setString(key: SettingsKeys.externalPlayerURLTemplate, value: externalPlayerTemplate)
        try await settingsManager.setBool(key: SettingsKeys.preferCachedStreams, value: preferCached)
        try await settingsManager.setBool(key: SettingsKeys.preferAtmosAudio, value: preferAtmos)
        try await settingsManager.setString(key: SettingsKeys.preferredHDRFormat, value: hdrPreference)
        try await settingsManager.setBool(key: SettingsKeys.runtimeDiagnosticsEnabled, value: runtimeDiagnosticsEnabled)
        try await settingsManager.setString(key: SettingsKeys.navigationLayout, value: navigationLayout)

        return AppState(settingsManager: settingsManager)
    }

    private func makeDatabase() async throws -> DatabaseManager {
        let database = try DatabaseManager(inMemoryNamed: "player-settings-view-\(UUID().uuidString)")
        try await database.migrate()
        return database
    }
}
