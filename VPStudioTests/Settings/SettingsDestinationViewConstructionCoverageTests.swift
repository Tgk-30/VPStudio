import Foundation
import SwiftUI
import Testing
@testable import VPStudio

@Suite("Settings Destination View Construction Coverage")
struct SettingsDestinationViewConstructionCoverageTests {
    @Test
    @MainActor
    func debridSettingsViewBuildsWithSupportedAndUnsupportedConfigsAndStatusBanners() {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let configs = [
            DebridConfig(
                id: "rd",
                serviceType: .realDebrid,
                apiTokenRef: "token-rd",
                isActive: true,
                priority: 0,
                createdAt: now,
                updatedAt: now
            ),
            DebridConfig(
                id: "easy",
                serviceType: .easyNews,
                apiTokenRef: "token-easy",
                isActive: false,
                priority: 1,
                createdAt: now,
                updatedAt: now
            ),
        ]

        let view = DebridSettingsView(
            initialConfigs: configs,
            initialShowingAddSheet: false,
            initialNewServiceType: .allDebrid,
            initialNewApiKey: " token ",
            initialSurfaceError: .unknown("surface failure"),
            initialTestingConfigID: "rd",
            initialUpdatingConfigID: "easy",
            initialValidationSuccessMessagesByConfigID: ["rd": "valid"],
            initialValidationErrorMessagesByConfigID: ["easy": "invalid"],
            disablesAutomaticTasks: true
        )
        SwiftUIViewDiagnosticHost.render(view.environment(AppState()), width: 760, height: 900)
    }

    @Test
    @MainActor
    func indexerSettingsViewBuildsWithNoticeErrorAndMixedRows() {
        let configs = [
            IndexerConfig(
                id: "jackett",
                name: "Jackett A",
                indexerType: .jackett,
                baseURL: "https://jackett.example",
                apiKey: "key",
                isActive: true,
                priority: 0,
                endpointPath: "/api/v2.0/indexers/all/results/torznab/api",
                categoryFilter: "5000",
                apiKeyTransport: .header
            ),
            IndexerConfig(
                id: "stremio",
                name: "Stremio X",
                indexerType: .stremio,
                baseURL: "https://stremio.example",
                apiKey: nil,
                isActive: false,
                priority: 1,
                endpointPath: "/manifest.json",
                categoryFilter: nil,
                apiKeyTransport: .query
            ),
        ]

        let view = IndexerSettingsView(
            initialConfigs: configs,
            initialIsShowingEditor: false,
            initialDraft: .new(),
            initialSurfaceError: .unknown("indexer failure"),
            initialNotice: .success("Saved."),
            initialTestingConfigID: "jackett",
            disablesAutomaticTasks: true
        )
        SwiftUIViewDiagnosticHost.render(view.environment(AppState()), width: 760, height: 900)
    }

    @Test
    @MainActor
    func playerSettingsViewBuildsWithCustomExternalTemplateValidationPath() {
        let view = PlayerSettingsView(
            initialPreferredQuality: .uhd4k,
            initialAutoPlay: false,
            initialHardwareDecoding: false,
            initialPlayerEngineStrategy: .adaptive,
            initialExternalPlayerApp: .custom,
            initialExternalPlayerTemplate: "player://open?url={raw_url}",
            initialPreferCached: false,
            initialPreferAtmos: false,
            initialHDRPreference: .dolbyVision,
            initialRuntimeDiagnosticsEnabled: true,
            initialNavigationLayout: .leftSidebar,
            initialSurfaceError: .unknown("player failure"),
            disablesAutomaticTasks: true
        )
        SwiftUIViewDiagnosticHost.render(view.environment(AppState()), width: 760, height: 980)
    }

    @Test
    @MainActor
    func metadataSettingsViewBuildsWithSavedAndTestingStates() {
        let view = MetadataSettingsView(
            initialOMDbApiKey: "omdb-key",
            initialBaselineOMDbApiKey: "omdb-key",
            initialIsSaved: true,
            initialIsTestingApiKey: true,
            initialSurfaceError: .unknown("metadata failure"),
            initialNotice: .warning("warning"),
            disablesAutomaticTasks: true
        )
        SwiftUIViewDiagnosticHost.render(view.environment(AppState()), width: 700, height: 760)
    }

    @Test
    @MainActor
    func subtitleSettingsViewBuildsAndRendersDefaultSections() {
        let view = SubtitleSettingsView()
        SwiftUIViewDiagnosticHost.render(view.environment(AppState()), width: 700, height: 820)
    }

    @Test
    @MainActor
    func settingsRootViewBuildsForEmptySearchAndNoResultsStates() {
        let warningStatus = SettingsDestinationStatus(
            message: "Missing API key",
            kind: .warning
        )
        let statuses: [SettingsDestination: SettingsDestinationStatus] = [
            .metadata: warningStatus,
            .debrid: SettingsDestinationStatus(message: "Connected", kind: .positive),
        ]

        let normal = SettingsView(
            initialQuery: "",
            initialDidLoadInitialSearch: true,
            initialIsRefreshingStatuses: false,
            initialDestinationStatuses: statuses,
            initialIsShowingResetSheet: false,
            initialRecentDestination: .metadata,
            disablesAutomaticTasks: true
        )
        SwiftUIViewDiagnosticHost.render(normal.environment(AppState()), width: 900, height: 980)

        let emptyState = SettingsView(
            initialQuery: "zzz-no-match",
            initialDidLoadInitialSearch: true,
            initialIsRefreshingStatuses: false,
            initialDestinationStatuses: statuses,
            initialIsShowingResetSheet: false,
            initialRecentDestination: .metadata,
            disablesAutomaticTasks: true
        )
        SwiftUIViewDiagnosticHost.render(emptyState.environment(AppState()), width: 900, height: 980)
    }
}
