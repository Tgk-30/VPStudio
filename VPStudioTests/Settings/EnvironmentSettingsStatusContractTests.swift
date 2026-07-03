import Foundation
import Testing
@testable import VPStudio

@Suite("Environment Settings Status Contracts")
struct EnvironmentSettingsStatusContractTests {
    @Test
    func settingsRowsUseSharedEnvironmentStatusPolicy() throws {
        let source = try contents(of: "VPStudio/Views/Windows/Settings/Destinations/EnvironmentSettingsView.swift")
        let normalized = source.components(separatedBy: .whitespacesAndNewlines).joined()

        #expect(source.contains("EnvironmentSettingsStatusLabel(status: status)"))
        #expect(source.contains("EnvironmentPreviewRowPolicy.standardRoomStatus("))
        #expect(source.contains("EnvironmentPreviewRowPolicy.cinemaStatus("))
        #expect(source.contains("EnvironmentPreviewRowPolicy.assetStatus("))
        #expect(source.contains("private var effectiveSelectedAssetID: String?"))
        #expect(source.contains("EnvironmentPreviewRowPolicy.effectiveSelectedAssetID("))
        #expect(source.contains("apple.logo") == false)
        #expect(source.contains("selectedAssetID: effectiveSelectedAssetID"))
        #expect(source.contains("EnvironmentSettingsCopyPolicy.autoOpenHelp"))
        #expect(source.contains("EnvironmentSettingsCopyPolicy.genreSuggestionHelp"))
        #expect(source.contains("EnvironmentSettingsErrorPresentationPolicy.displayMessage(for: error)"))
        #expect(!source.contains("environmentError = error.localizedDescription"))
        #expect(source.contains("selected immersive environment opens automatically"))
        #expect(source.contains("Apple Environment stays in the system window"))
        #expect(source.contains("saved tag matches the media genre"))
        #expect(source.contains("If nothing matches, playback stays in Apple Environment."))
        #expect(source.contains("selected environment opens automatically") == false)
        #expect(source.contains("saved tag matches the title") == false)
        #expect(source.contains("falling back to the neutral environment") == false)
        #expect(source.contains("Selected environments open when immersive playback starts") == false)
        #expect(source.contains("Active means the environment is currently open") == false)
        #expect(source.contains("private func shouldShowEnvironmentExitAction(for status: EnvironmentPreviewCardStatus) -> Bool"))
        #expect(source.contains("status == .active"))
        #expect(source.contains("Text(environmentExitActionTitle(for: status))"))
        #expect(source.contains("Text(environmentActionTitle(for: status))") == false)
        #expect(source.contains("\"Use Apple\"") == false)
        #expect(source.contains("@State private var isImportingEnvironment = false"))
        #expect(source.contains("Text(\"Importing\")"))
        #expect(source.contains(".disabled(isImportingEnvironment)"))
        #expect(source.contains("private var importEnvironmentRow: some View"))
        #expect(source.contains(".help(\"Supports \\(EnvironmentImportValidationPolicy.supportedExtensionDisplayList)"))
        #expect(source.contains("Task { await handleFileImport(result) }"))
        #expect(source.contains("private func handleFileImport(_ result: Result<[URL], Error>) async"))
        #expect(source.contains("guard !isImportingEnvironment else { return }"))
        #expect(source.contains("isImportingEnvironment = true"))
        #expect(source.contains("defer { isImportingEnvironment = false }"))
        #expect(source.contains("environmentError = nil"))
        #expect(source.contains("@State private var deletingAssetIDs: Set<String> = []"))
        #expect(source.contains("Label(\"Deleting\", systemImage: \"hourglass\")"))
        #expect(source.contains("private func isDeletingAsset(_ asset: EnvironmentAsset) -> Bool"))
        #expect(source.contains("guard !normalizedID.isEmpty,"))
        #expect(source.contains("!deletingAssetIDs.contains(normalizedID)"))
        #expect(source.contains("deletingAssetIDs.insert(normalizedID)"))
        #expect(source.contains("defer { deletingAssetIDs.remove(normalizedID) }"))
        #expect(source.contains(".disabled(isDeleting)"))
        #expect(source.contains("static let importedActionSpacing: CGFloat = 16"))
        #expect(source.contains("static let rowIconWidth: CGFloat = 32"))
        #expect(source.contains("static let standardActionColumnMinWidth: CGFloat = 148"))
        #expect(source.contains("static let importedActionColumnMinWidth: CGFloat = 184"))
        #expect(source.contains("static let primaryActionMinWidth: CGFloat = 108"))
        #expect(source.contains("static let deleteActionButtonSize: CGFloat = VPSpace.minTapTarget"))
        #expect(source.contains("EnvironmentSettingsLayoutPolicy.importedActionColumnMinWidth"))
        #expect(source.contains("EnvironmentSettingsLayoutPolicy.standardActionColumnMinWidth"))
        #expect(source.contains("Menu {"))
        #expect(source.contains("Label(\"Delete\", systemImage: \"trash\")"))
        #expect(source.contains("Image(systemName: \"ellipsis\")"))
        #expect(source.contains("EnvironmentSettingsLayoutPolicy.deleteActionButtonSize"))
        #expect(source.contains("Color.white.opacity(0.18)"))
        #expect(source.contains(".accessibilityLabel(\"More actions for \\(asset.name)\")"))
        #expect(source.contains("private func deleteEnvironmentButton(for asset: EnvironmentAsset, isDeleting: Bool) -> some View"))
        #expect(source.contains(".accessibilityHint(\"Includes deleting this imported environment after confirmation.\")"))
        #expect(source.contains("Section(\"Online Presets (Poly Haven HDRI)\")") == false)
        #expect(source.contains("private func onlinePresetRow(_ preset: CuratedEnvironmentPreset) -> some View") == false)
        #expect(source.contains("private func isPresetInstalled(_ preset: CuratedEnvironmentPreset) -> Bool") == false)
        #expect(source.contains("private func installedPresetAsset(_ preset: CuratedEnvironmentPreset) -> EnvironmentAsset?") == false)
        #expect(source.contains("private func installPreset(_ preset: CuratedEnvironmentPreset) async") == false)
        #expect(source.contains("@State private var installingPresetIDs: Set<String> = []") == false)
        #expect(source.contains("importCuratedPreset(preset)") == false)
        #expect(source.contains("private func activateEnvironmentAsset(_ asset: EnvironmentAsset) async"))
        #expect(source.contains("private func environmentMetadataText(_ value: String) -> some View"))
        #expect(source.contains("private func importedEnvironmentDetailLine(for asset: EnvironmentAsset) -> some View"))
        #expect(source.contains("ViewThatFits(in: .horizontal)"))
        #expect(source.contains("private func bundledEnvironmentMetadataText(for asset: EnvironmentAsset) -> String?"))
        #expect(source.contains("licenseName.localizedCaseInsensitiveCompare(\"Built-in\") != .orderedSame"))
        #expect(source.contains(".foregroundStyle(VPColor.textSecondary)"))
        #expect(source.contains("private func environmentSourceLink(_ sourceURL: URL) -> some View"))
        #expect(source.contains("Label(\"Source\", systemImage: \"arrow.up.right\")"))
        #expect(source.contains(".foregroundStyle(VPColor.info)"))
        #expect(source.contains("Link(\"Source\", destination:") == false)
        #expect(source.contains("Image(systemName: EnvironmentPreviewFallbackArtworkKind.standardRoom.iconName)"))
        #expect(source.contains(".foregroundStyle(.tertiary)") == false)
        #expect(source.contains(".foregroundStyle(.green)") == false)
        #expect(source.contains(".foregroundStyle(.secondary)") == false)
        #expect(source.contains("EnvironmentSettingsLayoutPolicy.bottomContentPadding"))
        #expect(source.contains("static let contentMaxWidth: CGFloat = 1120"))
        #expect(source.contains("static let bottomContentPadding: CGFloat = 96"))
        #expect(source.contains("static let bottomViewportInset: CGFloat = 64"))
        #expect(source.contains("static let bottomViewportScrimOpacity") == false)
        #expect(source.contains("static let minimumRowHeight: CGFloat = 64"))
        #expect(source.contains("static let sectionSpacing: CGFloat = 10"))
        #expect(source.contains("static let rowInsets = EdgeInsets(top: 6, leading: 22, bottom: 6, trailing: 22)"))
        #expect(source.contains("belowFoldSectionGuardHeight") == false)
        #expect(source.contains(".frame(height: EnvironmentSettingsLayoutPolicy.belowFoldSectionGuardHeight)") == false)
        #expect(source.contains(".contentMargins(.bottom, EnvironmentSettingsLayoutPolicy.bottomContentPadding, for: .scrollContent)"))
        #expect(source.contains("VPBottomViewportScrim(") == false)
        #expect(source.contains(".safeAreaInset(edge: .bottom, spacing: 0)"))
        #expect(source.contains(".frame(height: EnvironmentSettingsLayoutPolicy.bottomViewportInset)"))
        #expect(source.contains(".frame(maxWidth: EnvironmentSettingsLayoutPolicy.contentMaxWidth)"))
        #expect(source.contains(".environment(\\.defaultMinListRowHeight, EnvironmentSettingsLayoutPolicy.minimumRowHeight)"))
        #expect(source.contains(".listSectionSpacing(EnvironmentSettingsLayoutPolicy.sectionSpacing)"))
        #expect(source.contains(".listRowInsets(EnvironmentSettingsLayoutPolicy.rowInsets)"))
        #expect(source.contains(".listRowSeparator(.hidden)"))
        #expect(source.contains(".font(.subheadline)"))
        #expect(source.contains(".font(.title3.weight(.semibold))"))
        #expect(source.contains(".font(.footnote.weight(.semibold))"))
        #expect(source.contains(".controlSize(.regular)"))
        #expect(source.contains(".fixedSize(horizontal: false, vertical: true)"))
        #expect(source.contains("EnvironmentSettingsPassiveActionLabel("))
        #expect(source.contains("title: \"Player only\""))
        #expect(source.contains("EnvironmentSettingsValueBadge("))
        #expect(source.contains("title: EnvironmentPreviewRowPolicy.appleEnvironmentBenefitLabel"))
        #expect(source.contains("private struct EnvironmentSettingsValueBadge: View"))
        #expect(source.contains(".accessibilityLabel(\"\\(chip.title) environment status\")"))
        let curatedRange = try #require(source.range(of: "Section(\"Curated Environments\")"))
        let playbackRange = try #require(source.range(of: "Section(\"Playback\")"))
        let importedRange = try #require(source.range(of: "Section(\"Imported Environments\")"))
        let importRowRange = try #require(source.range(of: "importEnvironmentRow", range: importedRange.upperBound..<source.endIndex))
        let importedAssetsRange = try #require(source.range(of: "ForEach(assets.filter { $0.sourceType == .imported })", range: importedRange.upperBound..<source.endIndex))
        let importRowDefinitionRange = try #require(source.range(of: "private var importEnvironmentRow: some View"))
        let importRowDefinitionSource = String(source[importRowDefinitionRange.lowerBound..<source.endIndex])
        #expect(importRowDefinitionSource.contains("Text(\"No imported environments yet.\")"))
        #expect(importRowDefinitionSource.contains("ViewThatFits(in: .horizontal)"))
        #expect(importRowDefinitionSource.contains(".lineLimit(1)"))
        #expect(importRowDefinitionSource.contains(".fixedSize(horizontal: false, vertical: true)"))
        #expect(importRowDefinitionSource.contains(".frame(maxWidth: .infinity, alignment: .leading)"))
        #expect(curatedRange.lowerBound < playbackRange.lowerBound)
        #expect(playbackRange.lowerBound < importedRange.lowerBound)
        #expect(importRowRange.lowerBound < importedAssetsRange.lowerBound)
        #expect(normalized.contains("Button(\"Delete\",role:.destructive){pendingDeletion=nilTask{awaitdeleteImportedEnvironment(id:deletion.id)}}"))
        #expect(normalized.contains("ifasset.isActive{") == false)
        #expect(source.contains("Label(\"Selected\", systemImage: \"checkmark.circle.fill\")") == false)
        #expect(source.contains("Label(\"Active\", systemImage: \"checkmark.circle.fill\")") == false)
    }

    @Test
    func environmentSettingsRowsUseLegibleRoomContrast() throws {
        let source = try contents(of: "VPStudio/Design/Components/GlassSurface.swift")
        let rowStart = try #require(source.range(of: "struct VPEnvironmentListRowBackground: View"))
        let rowSource = String(source[rowStart.lowerBound..<source.endIndex])

        #expect(rowSource.contains(".fill(Color(red: 0.046, green: 0.052, blue: 0.060))"))
        #expect(rowSource.contains(".fill(Color.black.opacity(0.26))"))
        #expect(rowSource.contains("shape.strokeBorder(Color.white.opacity(0.18), lineWidth: 1)"))
    }

    @Test
    func environmentPreviewRowsUseSamePresetInstallRecovery() throws {
        let source = try contents(of: "VPStudio/Views/Windows/Discover/EnvironmentPreviewRow.swift")
        let normalized = source.components(separatedBy: .whitespacesAndNewlines).joined()

        #expect(source.contains("@State private var isImportingEnvironment = false"))
        #expect(source.contains("private var importButtonLabel: some View"))
        #expect(source.contains("Text(\"Importing\")"))
        #expect(source.contains(".disabled(isImportingEnvironment)"))
        #expect(source.contains("guard !isImportingEnvironment else { return }"))
        #expect(source.contains("isImportingEnvironment = true"))
        #expect(source.contains("defer { isImportingEnvironment = false }"))
        #expect(source.contains("@State private var deletingAssetIDs: Set<String> = []"))
        #expect(source.contains("private func isDeletingAsset(_ asset: EnvironmentAsset) -> Bool"))
        #expect(source.contains("var isDeleting: Bool = false"))
        #expect(source.contains("title: \"Deleting\""))
        #expect(source.contains("guard !normalizedID.isEmpty,"))
        #expect(source.contains("!deletingAssetIDs.contains(normalizedID)"))
        #expect(source.contains("deletingAssetIDs.insert(normalizedID)"))
        #expect(source.contains("defer { deletingAssetIDs.remove(normalizedID) }"))
        #expect(source.contains(".disabled(isDeleting)"))
        #expect(source.contains("private func isPresetInstalled(_ preset: CuratedEnvironmentPreset) -> Bool"))
        #expect(source.contains("private func installedPresetAsset(_ preset: CuratedEnvironmentPreset) -> EnvironmentAsset?"))
        #expect(source.contains("let isInstalled = isPresetInstalled(preset)"))
        #expect(source.contains("let installedAsset = installedPresetAsset(preset)"))
        #expect(source.contains("onSelect(installedAsset)"))
        #expect(source.contains("Text(\"Adding\")"))
        #expect(source.contains(".disabled(isInstalling)"))
        #expect(source.contains("let selectedAssetID = EnvironmentPreviewRowPolicy.effectiveSelectedAssetID("))
        #expect(normalized.contains("guard!isDeletingelse{return}"))
        #expect(normalized.contains("guard!isPresetInstalled(preset),!installingPresetIDs.contains(preset.id)else{return}"))
    }

    @Test
    func legacyEnvironmentPresetRowsUseSharedProviderIcons() throws {
        let source = try contents(of: "VPStudio/Views/Windows/ContentView.swift")
        let rowStart = try #require(source.range(of: "private func onlinePresetRow(_ preset: CuratedEnvironmentPreset) -> some View"))
        let rowEnd = try #require(source.range(of: "private func isPresetInstalled(_ preset: CuratedEnvironmentPreset)", range: rowStart.upperBound..<source.endIndex))
        let rowSource = String(source[rowStart.lowerBound..<rowEnd.lowerBound])

        #expect(rowSource.contains("EnvironmentPreviewRowPolicy.providerIconName(for: preset.provider)"))
        #expect(rowSource.contains("preset.provider == .polyHaven") == false)
        #expect(rowSource.contains("apple.logo") == false)
        #expect(rowSource.contains(".foregroundStyle(VPColor.success)"))
        #expect(rowSource.contains(".background(VPColor.success.opacity(0.12), in: Capsule())"))
        #expect(rowSource.contains("EnvironmentPreviewLayoutPolicy.roomLegibilityRowOpacity"))
        #expect(rowSource.contains("EnvironmentPreviewLayoutPolicy.roomLegibilityStrokeOpacity"))
        #expect(rowSource.contains("VPColor.contentPlane.opacity(0.56)"))
        #expect(rowSource.contains("let installedAsset = installedPresetAsset(preset)"))
        #expect(rowSource.contains("Task { await selectEnvironment(installedAsset) }"))
        #expect(rowSource.contains(".foregroundStyle(.green)") == false)
        #expect(rowSource.contains(".foregroundStyle(.secondary)") == false)
        #expect(rowSource.contains(".background(.green") == false)
        #expect(rowSource.contains(".glassSurface(.rest, cornerRadius: 14)") == false)
    }

    @Test
    func environmentErrorPresentationRedactsSensitiveProviderFailures() {
        let redacted = EnvironmentSettingsErrorPresentationPolicy.displayMessage(
            for: SecretBearingEnvironmentSettingsError()
        )

        #expect(redacted.contains("REDACTED"))
        #expect(!redacted.contains("environment-token-1234567890"))
        #expect(!redacted.contains("environment-client-secret-1234567890"))
    }

    private func contents(of relativePath: String) throws -> String {
        let absolutePath = repoRootURL().appendingPathComponent(relativePath).path
        return try String(contentsOfFile: absolutePath, encoding: .utf8)
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

private struct SecretBearingEnvironmentSettingsError: LocalizedError {
    var errorDescription: String? {
        "Environment import failed for https://assets.example.com/skybox.zip?token=environment-token-1234567890 clientSecret=environment-client-secret-1234567890"
    }
}
