import Foundation
import Testing
@testable import VPStudio

@Suite("Settings Destination Contracts Coverage")
struct SettingsDestinationContractsCoverageTests {
    // These tests are intentionally "source contract" tests:
    // they read the Swift source for low-coverage Settings destinations and assert
    // security/UX invariants without spawning UI runtimes, simulators, or network calls.

    @Test
    func traktSettingsView_doesNotExposeSecrets_andSupportsCopyingDeviceCode_andDisconnectIsDestructive() throws {
        let source = try loadSource(at: "VPStudio/Views/Windows/Settings/Destinations/TraktSettingsView.swift")

        // Secrets must be entered as SecureField.
        #expect(source.contains("SecureField(\"Client Secret\", text: $clientSecret)"))

        // No accidental plaintext secret rendering.
        expectNoPlaintextDisplays(of: ["clientSecret"], in: source)

        // Status copy contract for device code (clipboard write + accessible label).
        #expect(source.contains("accessibilityLabel(\"Copy Trakt device code\")"))
        #expect(
            source.contains("UIPasteboard.general.string = code")
                || source.contains("NSPasteboard.general.setString(code, forType: .string)")
        )

        // Disconnect should be explicitly destructive and route through the app-level cleanup.
        #expect(source.contains("Button(\"Disconnect\", role: .destructive)"))
        #expect(source.contains("try await appState.disconnectTrakt()"))
    }

    @Test
    func metadataSettingsView_usesSecureField_andValidationHelpers_andNeverDisplaysApiKeyPlaintext() throws {
        let source = try loadSource(at: "VPStudio/Views/Windows/Settings/Destinations/MetadataSettingsView.swift")

        #expect(source.contains("SecureField(\"OMDb API Key\", text: $omdbApiKey)"))
        #expect(source.contains("SecureField(\"TMDb API Key or Read Token\", text: $tmdbApiKey)"))
        #expect(source.contains("metadataPlanSelector("))
        #expect(source.contains("planTitle: \"OMDb Plan\""))
        #expect(source.contains("planTitle: \"TMDb Plan\""))
        #expect(source.contains("selectedPlanTitle: omdbPlan == .paid ? \"Paid\" : \"Free\""))
        #expect(source.contains("selectedPlanTitle: tmdbPlan == .paid ? \"Expanded\" : \"Standard\""))
        #expect(source.contains("hasUnsavedPlanChange: MetadataSettingsPolicy.hasUnsavedPlanChange("))
        #expect(source.contains("private func metadataPlanStateRow("))
        #expect(source.contains("systemImage: isUnsaved ? \"circle.dashed\" : \"checkmark.circle\""))
        #expect(source.contains("title: \"Save changes\""))
        #expect(source.contains("static let selectedPlanFill = VPColor.info.opacity(0.24)"))
        #expect(source.contains("static let selectedPlanStroke = VPColor.info.opacity(0.88)"))
        #expect(source.contains("MetadataSettingsPolicy.selectedPlanFill"))
        #expect(source.contains("MetadataSettingsPolicy.selectedPlanStroke"))
        #expect(source.contains("VPColor.accent.opacity(0.28)") == false)
        #expect(source.contains("VPColor.accent.opacity(0.95)") == false)
        #expect(source.contains("MetadataSettingsPolicy.normalizedAPIKey(omdbApiKey)"))
        #expect(source.contains("MetadataSettingsPolicy.hasUnsavedConfigurationChange("))
        #expect(source.contains("currentOMDb: omdbApiKey"))
        #expect(source.contains("baselineOMDb: initialOMDbApiKey"))
        #expect(source.contains("currentOMDbPlan: omdbPlan"))
        #expect(source.contains("baselineOMDbPlan: initialOMDbPlan"))
        #expect(source.contains("currentTMDb: tmdbApiKey"))
        #expect(source.contains("baselineTMDb: initialTMDbApiKey"))
        #expect(source.contains("currentTMDbPlan: tmdbPlan"))
        #expect(source.contains("baselineTMDbPlan: initialTMDbPlan"))
        #expect(source.contains("MetadataSettingsPolicy.shouldInvalidateSavedState("))
        #expect(source.contains("SettingsInputValidation.normalizedSecret(value)"))
        #expect(source.contains("SettingsInputValidation.hasUnsavedSecretChange(current: current, initial: baseline)"))

        expectNoPlaintextDisplays(of: ["omdbApiKey"], in: source)
        expectNoPlaintextDisplays(of: ["tmdbApiKey"], in: source)

        // Saving should use SettingsManager so empty/whitespace clears the stored secret deterministically.
        #expect(source.contains("appState.settingsManager.setString(key: SettingsKeys.omdbApiKey, value: configuration.omdbApiKey)"))
        #expect(source.contains("appState.settingsManager.setString(key: SettingsKeys.tmdbApiKey, value: configuration.tmdbApiKey)"))
        #expect(source.contains("appState.settingsManager.setString(key: SettingsKeys.omdbProviderPlan, value: configuration.omdbPlan.rawValue)"))
        #expect(source.contains("appState.settingsManager.setString(key: SettingsKeys.tmdbProviderPlan, value: configuration.tmdbPlan.rawValue)"))
        #expect(source.contains("NotificationCenter.default.post(name: .metadataApiKeyDidChange, object: nil)"))
        #expect(source.contains("notice = MetadataSettingsPolicy.missingAPIKeyNotice"))
        #expect(source.contains("MetadataSettingsPolicy.validationFailureDescription(for: firstFailure.error)"))
        #expect(source.contains("failureDescription: firstFailure.error.localizedDescription") == false)
        #expect(source.contains("metadataFooterActionButton("))
        #expect(source.contains("static let footerActionMinWidth"))
        #expect(source.contains("metadataStatusChip(title: \"Saved\", systemImage: \"checkmark.circle.fill\", tint: VPColor.success)"))
        #expect(source.contains("metadataStatusChip(title: \"Unsaved\", systemImage: \"circle.dashed\", tint: VPColor.warning)"))
        #expect(source.contains(".foregroundStyle(.green)") == false)
        #expect(source.contains("VPBackground()"))
        #expect(source.contains(".scrollContentBackground(.hidden)"))

        // Provider/service creation should be lazy (only inside explicit test action).
        let testFnRange = try requiredRange(of: "private func testMetadataAPIKeys() async {", in: source)
        let omdbUseRange = try requiredRange(
            of: "OMDbService(apiKey: omdbApiKey, includesPaidArtwork: configuration.omdbPlan.usesPaidResources)",
            in: source,
            range: testFnRange.lowerBound..<source.endIndex
        )
        let tmdbUseRange = try requiredRange(
            of: "TMDBService(apiKey: tmdbApiKey, plan: configuration.tmdbPlan)",
            in: source,
            range: testFnRange.lowerBound..<source.endIndex
        )
        #expect(testFnRange.lowerBound < omdbUseRange.lowerBound)
        #expect(testFnRange.lowerBound < tmdbUseRange.lowerBound)
    }

    @Test
    func settingsStatusIndicatorsUseSharedColorTokens() throws {
        let paths = [
            "VPStudio/Views/Windows/Settings/Destinations/MetadataSettingsView.swift",
            "VPStudio/Views/Windows/Settings/Destinations/DebridSettingsView.swift",
            "VPStudio/Views/Windows/Settings/Destinations/TraktSettingsView.swift",
            "VPStudio/Views/Windows/Settings/Destinations/AISettingsView.swift",
            "VPStudio/Views/Windows/Settings/Destinations/IMDbImportSettingsView.swift",
        ]
        let combinedSource = try paths
            .map(loadSource(at:))
            .joined(separator: "\n")

        #expect(combinedSource.contains("VPColor.success"))
        #expect(combinedSource.contains("VPColor.info"))
        #expect(combinedSource.contains(".foregroundStyle(.green)") == false)
        #expect(combinedSource.contains(".foregroundStyle(.blue)") == false)
        #expect(combinedSource.contains(".background(.green") == false)
    }

    @Test
    func subtitleSettingsView_openSubtitlesKeyIsSecure_andPersistsThroughSettingsManager_andNeverDisplaysApiKeyPlaintext() throws {
        let source = try loadSource(at: "VPStudio/Views/Windows/Settings/Destinations/SubtitleSettingsView.swift")
        let policySource = try loadSource(at: "VPStudio/Views/Windows/Settings/Destinations/SubtitleSettingsPolicy.swift")

        #expect(source.contains("SecureField(\"API Key\", text: $openSubsApiKey)"))
        expectNoPlaintextDisplays(of: ["openSubsApiKey"], in: source)

        // Persistence must route through SettingsManager so blank values delete securely (keychain cleanup lives there).
        #expect(source.contains("try await appState.settingsManager.setString(key: key, value: value)"))
        #expect(source.contains("if key == SettingsKeys.openSubtitlesApiKey {"))
        #expect(source.contains("NotificationCenter.default.post(name: .openSubtitlesDidChange, object: nil)"))
        #expect(source.contains("fontSize = SubtitleSettingsPolicy.resolvedFontSize("))
        #expect(policySource.contains("static let minFontSize: Double = 16"))
        #expect(policySource.contains("static let maxFontSize: Double = 48"))
        #expect(source.contains("Slider(value: $fontSize, in: 16...48"))
    }

    @Test
    func playerSettingsView_validatesCustomExternalPlayerTemplates_andDoesNotPersistArbitraryStringsBlindly() throws {
        let source = try loadSource(at: "VPStudio/Views/Windows/Settings/Destinations/PlayerSettingsView.swift")

        // Custom URL template validation must be present and surfaced in the UI.
        #expect(source.contains("ExternalPlayerRouting.validationResult(forCustomTemplate: externalPlayerTemplate)"))
        #expect(source.contains("case .invalid(let message):"))

        // Persistence should route through the policy encoder.
        #expect(source.contains("persist(PlayerSettingsPolicy.externalPlayerTemplateWrite(value))"))
    }

    @Test
    func debridSettingsView_secretsAreSecure_andDeleteCleansUpSecretStore_andValidationStatusDoesNotExposeToken() throws {
        let source = try loadSource(at: "VPStudio/Views/Windows/Settings/Destinations/DebridSettingsView.swift")

        // Add-service token entry must be secure.
        #expect(source.contains("SecureField(\"API Key\", text: $newApiKey)"))
        expectNoPlaintextDisplays(of: ["newApiKey"], in: source)

        // Delete flow must delete the config and its secret reference.
        let deleteFnRange = try requiredRange(of: "private func delete(_ config: DebridConfig) async {", in: source)
        let dbDeleteRange = try requiredRange(
            of: "try await appState.database.deleteDebridConfig(id: config.id)",
            in: source,
            range: deleteFnRange.lowerBound..<source.endIndex
        )
        let secretDeleteRange = try requiredRange(
            of: "try await appState.secretStore.deleteSecret(for: secretKey)",
            in: source,
            range: dbDeleteRange.lowerBound..<source.endIndex
        )
        #expect(dbDeleteRange.lowerBound < secretDeleteRange.lowerBound)

        // Rollback contract: if DB save fails after writing keychain, the secret is deleted.
        let saveFnRange = try requiredRange(of: "private func saveDebridConfig() async {", in: source)
        let secretSetRange = try requiredRange(
            of: "try await appState.secretStore.setSecret(normalizedApiKey, for: secretKey)",
            in: source,
            range: saveFnRange.lowerBound..<source.endIndex
        )
        let rollbackDeleteRange = try requiredRange(
            of: "try await appState.secretStore.deleteSecret(for: secretKey)",
            in: source,
            range: secretSetRange.lowerBound..<source.endIndex
        )
        #expect(secretSetRange.lowerBound < rollbackDeleteRange.lowerBound)

        // Validation UI should only ever show high-level status messages, not tokens.
        #expect(source.contains("DebridSettingsPolicy.successMessage"))
        #expect(!source.contains("Text(token"))
        #expect(source.contains("SecretReference.decode(config.apiTokenRef)"))
        #expect(source.contains("DebridSettingsPolicy.fallbackToken(from: config.apiTokenRef)"))
    }

    @Test
    func playerSettingsView_persistsThenMirrorsRuntimeStateUpdates() throws {
        let source = try loadSource(at: "VPStudio/Views/Windows/Settings/Destinations/PlayerSettingsView.swift")

        #expect(source.contains("try await performPersistence(write)"))
        #expect(source.contains("applyAppStateMirrorUpdate(for: write)"))
        #expect(source.contains("appState.runtimeDiagnosticsEnabled = value"))
        #expect(source.contains("appState.navigationLayout = value"))
    }

    @Test
    func simklSettingsView_disconnectClearsAllSavedAuthorization_andStatusNeverDisplaysTokens() throws {
        let source = try loadSource(at: "VPStudio/Views/Windows/Settings/Destinations/SimklSettingsView.swift")

        #expect(source.contains("Button(\"Disconnect\", role: .destructive)"))
        #expect(source.contains("SettingsInputValidation.hasSimklCredentials("))

        // Clearing should nil all known saved values (SettingsManager handles secret deletion).
        #expect(source.contains("SettingsKeys.simklClientId, value: nil"))
        #expect(source.contains("SettingsKeys.simklAccessToken, value: nil"))
        #expect(source.contains("SettingsKeys.simklRefreshToken, value: nil"))

        expectNoPlaintextDisplays(of: ["clientId", "accessToken", "refreshToken"], in: source)
    }

    // MARK: - Helpers

    private func loadSource(at relativePath: String) throws -> String {
        try String(contentsOf: repoRootURL().appendingPathComponent(relativePath), encoding: .utf8)
    }

    private func expectNoPlaintextDisplays(of identifiers: [String], in source: String) {
        for identifier in identifiers {
            // Explicit view rendering of the identifier, or interpolating it into UI strings, is forbidden.
            #expect(!source.contains("Text(\(identifier))"))
            #expect(!source.contains("\\(\(identifier))"))
            #expect(!source.contains("Label(\(identifier)"))
        }
    }

    private func requiredRange(
        of needle: String,
        in source: String,
        range searchRange: Range<String.Index>? = nil
    ) throws -> Range<String.Index> {
        guard let range = source.range(of: needle, range: searchRange) else {
            Issue.record("Missing expected source text: \(needle)")
            throw NSError(
                domain: "SettingsDestinationContractsCoverageTests",
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
