import Foundation
import Testing

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
        #expect(source.contains("EnvironmentPreviewRowPolicy.providerIconName(for: preset.provider)"))
        #expect(source.contains("apple.logo") == false)
        #expect(source.contains("selectedAssetID: effectiveSelectedAssetID"))
        #expect(source.contains("selected environment opens automatically"))
        #expect(source.contains("Active means the room is currently open"))
        #expect(source.contains("status == .active ? \"Exit\" : \"Clear\""))
        #expect(source.contains("@State private var isImportingEnvironment = false"))
        #expect(source.contains("Text(\"Importing\")"))
        #expect(source.contains(".disabled(isImportingEnvironment)"))
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
        #expect(source.contains("private func isPresetInstalled(_ preset: CuratedEnvironmentPreset) -> Bool"))
        #expect(source.contains("let isInstalled = isPresetInstalled(preset)"))
        #expect(source.contains(".foregroundStyle(VPColor.success)"))
        #expect(source.contains("private func environmentMetadataText(_ value: String) -> some View"))
        #expect(source.contains(".foregroundStyle(VPColor.textSecondary)"))
        #expect(source.contains("private func environmentSourceLink(_ sourceURL: URL) -> some View"))
        #expect(source.contains("Label(\"Source\", systemImage: \"arrow.up.right\")"))
        #expect(source.contains(".foregroundStyle(VPColor.info)"))
        #expect(source.contains("Link(\"Source\", destination:") == false)
        #expect(source.contains(".foregroundStyle(.tertiary)") == false)
        #expect(source.contains(".foregroundStyle(.green)") == false)
        #expect(source.contains("Text(\"Adding\")"))
        #expect(source.contains(".disabled(isInstalling)"))
        #expect(normalized.contains("Button(\"Delete\",role:.destructive){pendingDeletion=nilTask{awaitdeleteImportedEnvironment(id:deletion.id)}}"))
        #expect(normalized.contains("guard!isPresetInstalled(preset),!installingPresetIDs.contains(preset.id)else{return}"))
        #expect(normalized.contains("ifasset.isActive{") == false)
        #expect(source.contains("Label(\"Selected\", systemImage: \"checkmark.circle.fill\")") == false)
        #expect(source.contains("Label(\"Active\", systemImage: \"checkmark.circle.fill\")") == false)
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
        #expect(source.contains("let isInstalled = isPresetInstalled(preset)"))
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
        #expect(rowSource.contains(".foregroundStyle(.green)") == false)
        #expect(rowSource.contains(".background(.green") == false)
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
