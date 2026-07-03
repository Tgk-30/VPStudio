import Foundation
import Testing
@testable import VPStudio

// MARK: - Helpers

private func makeDatabase(named fileName: String) async throws -> (DatabaseManager, URL) {
    let rootDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    try FileManager.default.createDirectory(at: rootDir, withIntermediateDirectories: true)
    let database = try DatabaseManager(inMemoryNamed: "\(fileName)-\(UUID().uuidString)")
    try await database.migrate()
    return (database, rootDir)
}

// MARK: - EnvironmentAsset Model Tests

@Suite
struct EnvironmentAssetModelTests {

    @Test func environmentAssetPropertiesMatchInitialization() {
        let now = Date()
        let asset = EnvironmentAsset(
            id: "test-id",
            name: "Cinema",
            sourceType: .bundled,
            assetPath: "/path/to/cinema.hdr",
            thumbnailPath: "/thumb.jpg",
            licenseName: "CC0",
            sourceAttributionURL: "https://example.com",
            previewImagePath: "/preview.jpg",
            hdriYawOffset: 42.0,
            createdAt: now,
            isActive: true
        )

        #expect(asset.id == "test-id")
        #expect(asset.name == "Cinema")
        #expect(asset.sourceType == .bundled)
        #expect(asset.assetPath == "/path/to/cinema.hdr")
        #expect(asset.thumbnailPath == "/thumb.jpg")
        #expect(asset.licenseName == "CC0")
        #expect(asset.sourceAttributionURL == "https://example.com")
        #expect(asset.previewImagePath == "/preview.jpg")
        #expect(asset.hdriYawOffset == 42.0)
        #expect(asset.createdAt == now)
        #expect(asset.isActive == true)
    }

    @Test func environmentAssetDefaultValues() {
        let asset = EnvironmentAsset(
            id: "id",
            name: "Name",
            sourceType: .imported,
            assetPath: "/path"
        )

        #expect(asset.thumbnailPath == nil)
        #expect(asset.licenseName == nil)
        #expect(asset.sourceAttributionURL == nil)
        #expect(asset.previewImagePath == nil)
        #expect(asset.hdriYawOffset == nil)
        #expect(asset.isActive == false)
    }

    @Test func environmentAssetCodableRoundTrip() throws {
        let now = Date()
        let original = EnvironmentAsset(
            id: "codable-id",
            name: "Codable Test",
            sourceType: .imported,
            assetPath: "/env.usdz",
            thumbnailPath: "/thumb.png",
            licenseName: "MIT",
            sourceAttributionURL: "https://mit.edu",
            previewImagePath: "/preview.png",
            hdriYawOffset: -15.5,
            createdAt: now,
            isActive: true
        )

        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(EnvironmentAsset.self, from: data)

        #expect(decoded.id == original.id)
        #expect(decoded.name == original.name)
        #expect(decoded.sourceType == original.sourceType)
        #expect(decoded.assetPath == original.assetPath)
        #expect(decoded.thumbnailPath == original.thumbnailPath)
        #expect(decoded.licenseName == original.licenseName)
        #expect(decoded.sourceAttributionURL == original.sourceAttributionURL)
        #expect(decoded.previewImagePath == original.previewImagePath)
        #expect(decoded.hdriYawOffset == original.hdriYawOffset)
        #expect(decoded.isActive == original.isActive)
    }

    @Test func environmentAssetEquatableSameIdAndValues() {
        let createdAt = Date(timeIntervalSince1970: 1000)
        let assetA = EnvironmentAsset(
            id: "same", name: "A", sourceType: .bundled, assetPath: "/a.hdr", createdAt: createdAt, isActive: false
        )
        let assetB = EnvironmentAsset(
            id: "same", name: "A", sourceType: .bundled, assetPath: "/a.hdr", createdAt: createdAt, isActive: false
        )
        #expect(assetA == assetB)
    }

    @Test func environmentAssetEquatableDifferentValues() {
        let assetA = EnvironmentAsset(
            id: "same", name: "A", sourceType: .bundled, assetPath: "/a.hdr", isActive: false
        )
        let assetB = EnvironmentAsset(
            id: "same", name: "B", sourceType: .imported, assetPath: "/b.hdr", isActive: true
        )
        #expect(assetA != assetB)
    }

    @Test func environmentAssetSourceTypeRawValues() {
        #expect(EnvironmentAssetSourceType.bundled.rawValue == "bundled")
        #expect(EnvironmentAssetSourceType.imported.rawValue == "imported")
    }

    @Test func environmentAssetSourceTypeCaseIterable() {
        let all = EnvironmentAssetSourceType.allCases
        #expect(all.contains(.bundled))
        #expect(all.contains(.imported))
        #expect(all.count == 2)
    }

    @Test func environmentAssetSourceTypeCodableRoundTrip() throws {
        for source in EnvironmentAssetSourceType.allCases {
            let data = try JSONEncoder().encode(source)
            let decoded = try JSONDecoder().decode(EnvironmentAssetSourceType.self, from: data)
            #expect(decoded == source)
        }
    }

    @Test func environmentAssetDatabaseTableName() {
        #expect(EnvironmentAsset.databaseTableName == "environment_assets")
    }

    @Test func environmentAssetIsActiveBooleanStorage() {
        let active = EnvironmentAsset(id: "a", name: "Active", sourceType: .bundled, assetPath: "/a", isActive: true)
        let inactive = EnvironmentAsset(id: "b", name: "Inactive", sourceType: .bundled, assetPath: "/b", isActive: false)
        #expect(active.isActive == true)
        #expect(inactive.isActive == false)
    }
}

@Suite("Environment URL Policy")
struct EnvironmentURLPolicyTests {
    @Test func attributionLinksOnlyAllowWebSchemes() {
        #expect(EnvironmentURLPolicy.webURL(from: "https://example.com/source")?.scheme == "https")
        #expect(EnvironmentURLPolicy.webURL(from: "http://example.com/source")?.scheme == "http")
        #expect(EnvironmentURLPolicy.webURL(from: "https://example.com/source?asset=cinema")?.scheme == "https")
        #expect(EnvironmentURLPolicy.webURL(from: "file:///etc/passwd") == nil)
        #expect(EnvironmentURLPolicy.webURL(from: "javascript:alert(1)") == nil)
        #expect(EnvironmentURLPolicy.webURL(from: "data:text/plain,hello") == nil)
        #expect(EnvironmentURLPolicy.webURL(from: "https://user:password@example.com/source") == nil)
        #expect(EnvironmentURLPolicy.webURL(from: "https://example.com/source?token=secret") == nil)
        #expect(EnvironmentURLPolicy.webURL(from: "https://example.com/source?APIKey=secret") == nil)
        #expect(EnvironmentURLPolicy.webURL(from: "https://example.com/source?signature=abc") == nil)
    }

    @Test func presetDownloadsRequireHTTPS() {
        #expect(EnvironmentURLPolicy.webURL(from: "https://example.com/sky.hdr", requiresHTTPS: true) != nil)
        #expect(EnvironmentURLPolicy.webURL(from: "https://example.com/download?asset=sky", requiresHTTPS: true) != nil)
        #expect(EnvironmentURLPolicy.webURL(from: "http://example.com/sky.hdr", requiresHTTPS: true) == nil)
        #expect(EnvironmentURLPolicy.webURL(from: "https://token@example.com/sky.hdr", requiresHTTPS: true) == nil)
        #expect(EnvironmentURLPolicy.webURL(from: "https://example.com/sky.hdr?access_token=secret", requiresHTTPS: true) == nil)
    }

    @Test func webURLsRejectLocalAndPrivateNetworkHosts() {
        let blockedHosts = [
            "localhost",
            "preview.local",
            "127.0.0.1",
            "10.1.2.3",
            "172.16.0.10",
            "172.31.255.1",
            "192.0.0.8",
            "192.0.2.10",
            "192.168.1.2",
            "169.254.10.20",
            "2130706433",
            "0177.0.0.1",
            "0x7f.0.0.1",
            "127.1",
            "0300.0250.01.02",
            "0xc0a80102",
            "intranet",
            "media.internal",
            "router.home.arpa",
            "[::1]",
            "[0:0:0:0:0:0:0:0]",
            "[0:0:0:0:0:0:0:1]",
            "[fd00::1]",
            "[fe80::1]",
            "[100::1]",
            "[64:ff9b::192.0.2.33]",
            "[2001:db8::1]",
            "[::ffff:127.0.0.1]",
            "[::ffff:7f00:1]",
            "[0:0:0:0:0:ffff:127.0.0.1]",
            "[0:0:0:0:0:ffff:7f00:1]",
            "[0:0:0:0:0:0:127.0.0.1]",
        ]

        for host in blockedHosts {
            #expect(EnvironmentURLPolicy.webURL(from: "https://\(host)/sky.hdr", requiresHTTPS: true) == nil)
        }

        #expect(EnvironmentURLPolicy.webURL(from: "https://example.com/sky.hdr", requiresHTTPS: true) != nil)
        #expect(EnvironmentURLPolicy.webURL(from: "https://8.8.8.8/sky.hdr", requiresHTTPS: true) != nil)
        #expect(EnvironmentURLPolicy.webURL(from: "https://192.0.78.9/sky.hdr", requiresHTTPS: true) != nil)
    }

    @Test func storedPreviewPathsRequireAbsoluteLocalFiles() {
        #expect(EnvironmentURLPolicy.absoluteFileURL(fromStoredPath: "/tmp/sky.hdr")?.isFileURL == true)
        #expect(EnvironmentURLPolicy.absoluteFileURL(fromStoredPath: "relative/sky.hdr") == nil)
        #expect(EnvironmentURLPolicy.absoluteFileURL(fromStoredPath: "bundle://SkyDomePreview.png") == nil)
    }

    @Test func fileURLInsideDirectoryUsesPathComponents() {
        let root = URL(fileURLWithPath: "/tmp/vpstudio/env", isDirectory: true)
        #expect(EnvironmentURLPolicy.fileURL(URL(fileURLWithPath: "/tmp/vpstudio/env/sky.hdr"), isInside: root))
        #expect(!EnvironmentURLPolicy.fileURL(URL(fileURLWithPath: "/tmp/vpstudio/env2/sky.hdr"), isInside: root))
        #expect(!EnvironmentURLPolicy.fileURL(URL(fileURLWithPath: "/tmp/vpstudio/env"), isInside: root))
    }

    @Test func fileURLInsideDirectoryRejectsSymlinkEscapes() throws {
        let tempRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("vpstudio-env-policy-\(UUID().uuidString)", isDirectory: true)
        let managedRoot = tempRoot.appendingPathComponent("managed", isDirectory: true)
        let outsideRoot = tempRoot.appendingPathComponent("outside", isDirectory: true)
        try FileManager.default.createDirectory(at: managedRoot, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: outsideRoot, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempRoot) }

        let outsideFile = outsideRoot.appendingPathComponent("escape.hdr")
        _ = FileManager.default.createFile(atPath: outsideFile.path, contents: Data())
        let symlink = managedRoot.appendingPathComponent("escape.hdr")
        try FileManager.default.createSymbolicLink(at: symlink, withDestinationURL: outsideFile)

        #expect(!EnvironmentURLPolicy.fileURL(symlink, isInside: managedRoot))
    }

    @Test func bundleResourcePathsRejectTraversalComponents() {
        #expect(EnvironmentURLPolicy.bundleResourceURL(relativePath: "../SkyDomePreview.png", in: .main) == nil)
        #expect(EnvironmentURLPolicy.bundleResourceURL(relativePath: "Environments/../SkyDomePreview.png", in: .main) == nil)
        #expect(EnvironmentURLPolicy.bundleResourceURL(relativePath: "Environments\\SkyDomePreview.png", in: .main) == nil)
    }
}

// MARK: - CuratedEnvironmentPreset Model Tests

@Suite
struct CuratedEnvironmentPresetModelTests {

    @Test func curatedPresetPropertiesMatchInitialization() {
        let preset = CuratedEnvironmentPreset(
            id: "preset-1",
            name: "Theater",
            description: "A nice theater",
            provider: .official,
            downloadURL: URL(string: "https://example.com/theater.hdr")!,
            sourceAttributionURL: "https://example.com",
            licenseName: "CC0",
            defaultHdriYawOffset: 12.0
        )

        #expect(preset.id == "preset-1")
        #expect(preset.name == "Theater")
        #expect(preset.description == "A nice theater")
        #expect(preset.provider == .official)
        #expect(preset.downloadURL.absoluteString == "https://example.com/theater.hdr")
        #expect(preset.sourceAttributionURL == "https://example.com")
        #expect(preset.licenseName == "CC0")
        #expect(preset.defaultHdriYawOffset == 12.0)
    }

    @Test func curatedPresetNilYawOffset() {
        let preset = CuratedEnvironmentPreset(
            id: "preset-nil",
            name: "Void",
            description: "Empty",
            provider: .polyHaven,
            downloadURL: URL(string: "https://example.com/void.hdr")!,
            sourceAttributionURL: "https://example.com",
            licenseName: "CC0",
            defaultHdriYawOffset: nil
        )
        #expect(preset.defaultHdriYawOffset == nil)
    }

    @Test func curatedPresetEquatable() {
        let a = CuratedEnvironmentPreset(
            id: "x", name: "X", description: "D", provider: .github,
            downloadURL: URL(string: "https://a.com")!,
            sourceAttributionURL: "https://a.com", licenseName: "MIT"
        )
        let b = CuratedEnvironmentPreset(
            id: "x", name: "X", description: "D", provider: .github,
            downloadURL: URL(string: "https://a.com")!,
            sourceAttributionURL: "https://a.com", licenseName: "MIT"
        )
        let c = CuratedEnvironmentPreset(
            id: "y", name: "Y", description: "D", provider: .github,
            downloadURL: URL(string: "https://a.com")!,
            sourceAttributionURL: "https://a.com", licenseName: "MIT"
        )
        #expect(a == b)
        #expect(a != c)
    }

    @Test func curatedProviderDisplayNames() {
        #expect(CuratedEnvironmentProvider.official.displayName == "Official")
        #expect(CuratedEnvironmentProvider.github.displayName == "GitHub")
        #expect(CuratedEnvironmentProvider.polyHaven.displayName == "Poly Haven")
    }

    @Test func curatedProviderCaseIterable() {
        let all = CuratedEnvironmentProvider.allCases
        #expect(all.contains(.official))
        #expect(all.contains(.github))
        #expect(all.contains(.polyHaven))
        #expect(all.count == 3)
    }

    @Test func curatedProviderCodableRoundTrip() throws {
        for provider in CuratedEnvironmentProvider.allCases {
            let data = try JSONEncoder().encode(provider)
            let decoded = try JSONDecoder().decode(CuratedEnvironmentProvider.self, from: data)
            #expect(decoded == provider)
        }
    }

    @Test func onlinePresetsAreNotEmpty() {
        let presets = EnvironmentCatalogManager.onlinePresets
        #expect(!presets.isEmpty)
    }

    @Test func onlinePresetsHaveValidDownloadURLs() {
        for preset in EnvironmentCatalogManager.onlinePresets {
            #expect(!preset.downloadURL.absoluteString.isEmpty)
            #expect(preset.downloadURL.scheme != nil)
        }
    }

    @Test func onlinePresetsHaveNamesAndDescriptions() {
        for preset in EnvironmentCatalogManager.onlinePresets {
            #expect(!preset.name.isEmpty)
            #expect(!preset.description.isEmpty)
        }
    }

    @Test func onlinePresetsHaveLicenseNames() {
        for preset in EnvironmentCatalogManager.onlinePresets {
            #expect(!preset.licenseName.isEmpty)
        }
    }

    @Test func onlinePresetsAreHDROrEXR() {
        for preset in EnvironmentCatalogManager.onlinePresets {
            let ext = preset.downloadURL.pathExtension.lowercased()
            #expect(ext == "hdr" || ext == "exr")
        }
    }

    @Test func onlinePresetsSourceAttributionIsHTTPS() {
        for preset in EnvironmentCatalogManager.onlinePresets {
            #expect(preset.sourceAttributionURL.hasPrefix("https://"))
        }
    }
}

// MARK: - EnvironmentCatalogManager Behavior Tests

@Suite(.serialized)
struct EnvironmentCatalogManagerBehaviorTests {

    @Test func bootstrapCuratedAssetsSeedsBundledSkyDomeOnFreshInstall() async throws {
        let (database, rootDir) = try await makeDatabase(named: "manager-bootstrap-skydome.sqlite")
        defer { try? FileManager.default.removeItem(at: rootDir) }

        let manager = EnvironmentCatalogManager(
            database: database,
            environmentsDirectory: rootDir.appendingPathComponent("env", isDirectory: true)
        )
        try await manager.bootstrapCuratedAssets()

        let assets = try await manager.fetchAssets()
        let skyDome = assets.first { $0.id == EnvironmentCatalogManager.bundledSkyDomeID }
        #expect(skyDome != nil)
        #expect(skyDome?.sourceType == .bundled)
        #expect(skyDome?.assetPath == EnvironmentCatalogManager.bundledSkyDomeAssetPath)
        #expect(skyDome?.assetPath.hasPrefix("bundle://") == true)
        // Bundled curated default must carry its mood tag so genre auto-match resolves it.
        #expect(skyDome?.environmentTag == GenreEnvironmentSuggestionPolicy.neutralDefault.matchKey)
    }

    @Test func bootstrapSeedsSkyDomeWithoutSelectingItWhenNothingElseActive() async throws {
        let (database, rootDir) = try await makeDatabase(named: "manager-bootstrap-active.sqlite")
        defer { try? FileManager.default.removeItem(at: rootDir) }

        let manager = EnvironmentCatalogManager(
            database: database,
            environmentsDirectory: rootDir.appendingPathComponent("env", isDirectory: true)
        )
        try await manager.bootstrapCuratedAssets()

        let active = try await manager.activeAsset()
        let preferred = try await database.getSetting(key: SettingsKeys.preferredEnvironment)
        let fallback = try await manager.asset(matchingTag: GenreEnvironmentSuggestionPolicy.neutralDefault.matchKey)
        #expect(active == nil)
        #expect(preferred == nil)
        #expect(fallback?.id == EnvironmentCatalogManager.bundledSkyDomeID)
    }

    @Test func bootstrapClearsLegacyImplicitSkyDomeSelectionWithoutPreferredEnvironment() async throws {
        let (database, rootDir) = try await makeDatabase(named: "manager-bootstrap-legacy-default.sqlite")
        defer { try? FileManager.default.removeItem(at: rootDir) }

        try await database.saveEnvironmentAsset(EnvironmentAsset(
            id: EnvironmentCatalogManager.bundledSkyDomeID,
            name: "Sky Dome",
            sourceType: .bundled,
            assetPath: EnvironmentCatalogManager.bundledSkyDomeAssetPath,
            isActive: true
        ))

        let manager = EnvironmentCatalogManager(
            database: database,
            environmentsDirectory: rootDir.appendingPathComponent("env", isDirectory: true)
        )
        try await manager.bootstrapCuratedAssets()

        let active = try await manager.activeAsset()
        let preferred = try await database.getSetting(key: SettingsKeys.preferredEnvironment)
        let cleared = try await database.getSetting(key: SettingsKeys.activeEnvironmentSelectionCleared)
        #expect(active == nil)
        #expect(preferred == nil)
        #expect(cleared == nil)
    }

    @Test func bootstrapPreservesExplicitPreferredSkyDomeSelection() async throws {
        let (database, rootDir) = try await makeDatabase(named: "manager-bootstrap-preferred-default.sqlite")
        defer { try? FileManager.default.removeItem(at: rootDir) }

        try await database.saveEnvironmentAsset(EnvironmentAsset(
            id: EnvironmentCatalogManager.bundledSkyDomeID,
            name: "Sky Dome",
            sourceType: .bundled,
            assetPath: EnvironmentCatalogManager.bundledSkyDomeAssetPath,
            isActive: true
        ))
        try await database.setSetting(
            key: SettingsKeys.preferredEnvironment,
            value: EnvironmentCatalogManager.bundledSkyDomeID
        )

        let manager = EnvironmentCatalogManager(
            database: database,
            environmentsDirectory: rootDir.appendingPathComponent("env", isDirectory: true)
        )
        try await manager.bootstrapCuratedAssets()

        let active = try await manager.activeAsset()
        let preferred = try await database.getSetting(key: SettingsKeys.preferredEnvironment)
        #expect(active?.id == EnvironmentCatalogManager.bundledSkyDomeID)
        #expect(preferred == EnvironmentCatalogManager.bundledSkyDomeID)
    }

    @Test func bootstrapRespectsExplicitlyClearedActiveSelection() async throws {
        let (database, rootDir) = try await makeDatabase(named: "manager-bootstrap-cleared-active.sqlite")
        defer { try? FileManager.default.removeItem(at: rootDir) }

        let manager = EnvironmentCatalogManager(
            database: database,
            environmentsDirectory: rootDir.appendingPathComponent("env", isDirectory: true)
        )
        try await manager.bootstrapCuratedAssets()
        try await manager.clearActiveAsset()
        try await manager.bootstrapCuratedAssets()

        let active = try await manager.activeAsset()
        let cleared = try await database.getSetting(key: SettingsKeys.activeEnvironmentSelectionCleared)
        #expect(active == nil)
        #expect(cleared == "1")
    }

    @Test func activatingAssetClearsExplicitStandardRoomSelection() async throws {
        let (database, rootDir) = try await makeDatabase(named: "manager-activate-after-clear.sqlite")
        defer { try? FileManager.default.removeItem(at: rootDir) }

        let manager = EnvironmentCatalogManager(
            database: database,
            environmentsDirectory: rootDir.appendingPathComponent("env", isDirectory: true)
        )
        try await manager.bootstrapCuratedAssets()
        try await manager.clearActiveAsset()
        try await manager.activateAsset(id: EnvironmentCatalogManager.bundledSkyDomeID)

        let active = try await manager.activeAsset()
        let cleared = try await database.getSetting(key: SettingsKeys.activeEnvironmentSelectionCleared)
        let preferred = try await database.getSetting(key: SettingsKeys.preferredEnvironment)
        #expect(active?.id == EnvironmentCatalogManager.bundledSkyDomeID)
        #expect(cleared == nil)
        #expect(preferred == EnvironmentCatalogManager.bundledSkyDomeID)
    }

    @Test func bootstrapIsIdempotentForSkyDome() async throws {
        let (database, rootDir) = try await makeDatabase(named: "manager-bootstrap-idempotent.sqlite")
        defer { try? FileManager.default.removeItem(at: rootDir) }

        let manager = EnvironmentCatalogManager(
            database: database,
            environmentsDirectory: rootDir.appendingPathComponent("env", isDirectory: true)
        )
        try await manager.bootstrapCuratedAssets()
        try await manager.bootstrapCuratedAssets()

        let skyDomes = try await manager.fetchAssets().filter {
            $0.id == EnvironmentCatalogManager.bundledSkyDomeID
        }
        #expect(skyDomes.count == 1)
    }

    @Test func skyDomeBundledAssetResolvesFromResourceBundle() async throws {
        // Guards the resource path/subdirectory: a `bundle://` curated default must
        // resolve to an on-disk URL via the resolver the same way the immersive view does.
        // Skipped when the test bundle does not ship the SkyDome resource (e.g. SwiftPM
        // CI bundle without the app Resources flattened in).
        let (database, rootDir) = try await makeDatabase(named: "manager-skydome-resolve.sqlite")
        defer { try? FileManager.default.removeItem(at: rootDir) }

        let manager = EnvironmentCatalogManager(database: database)
        let asset = EnvironmentAsset(
            id: EnvironmentCatalogManager.bundledSkyDomeID,
            name: "Sky Dome",
            sourceType: .bundled,
            assetPath: EnvironmentCatalogManager.bundledSkyDomeAssetPath
        )
        let resolved = await manager.resolvedAssetURL(for: asset)
        if let resolved {
            #expect(FileManager.default.fileExists(atPath: resolved.path))
            #expect(resolved.pathExtension.lowercased() == "usdz")
        }
    }

    @Test func skyDomeBundledAssetRoutesToCustomEnvironmentSpace() async throws {
        let (database, rootDir) = try await makeDatabase(named: "manager-skydome-space.sqlite")
        defer { try? FileManager.default.removeItem(at: rootDir) }

        let manager = EnvironmentCatalogManager(database: database)
        let asset = EnvironmentAsset(
            id: EnvironmentCatalogManager.bundledSkyDomeID,
            name: "Sky Dome",
            sourceType: .bundled,
            assetPath: EnvironmentCatalogManager.bundledSkyDomeAssetPath
        )
        #expect(await manager.immersiveSpaceID(for: asset) == "customEnvironment")
    }

    @Test func activeAssetReturnsNilWhenDatabaseIsEmpty() async throws {
        let (database, rootDir) = try await makeDatabase(named: "manager-active-nil.sqlite")
        defer { try? FileManager.default.removeItem(at: rootDir) }

        let manager = EnvironmentCatalogManager(
            database: database,
            environmentsDirectory: rootDir.appendingPathComponent("env", isDirectory: true)
        )
        let active = try await manager.activeAsset()
        #expect(active == nil)
    }

    @Test func activateAssetUpdatesActiveFlag() async throws {
        let (database, rootDir) = try await makeDatabase(named: "manager-activate.sqlite")
        defer { try? FileManager.default.removeItem(at: rootDir) }

        let manager = EnvironmentCatalogManager(
            database: database,
            environmentsDirectory: rootDir.appendingPathComponent("env", isDirectory: true),
            assetValidator: { _ in true }
        )

        let source = rootDir.appendingPathComponent("env.hdr")
        try Data("fake-hdr".utf8).write(to: source)
        let imported = try await manager.importEnvironment(from: source)

        try await manager.activateAsset(id: imported.id)
        let active = try await manager.activeAsset()
        #expect(active?.id == imported.id)
        #expect(active?.isActive == true)
    }

    @Test func activateAssetDeactivatesPreviousAsset() async throws {
        let (database, rootDir) = try await makeDatabase(named: "manager-activate-switch.sqlite")
        defer { try? FileManager.default.removeItem(at: rootDir) }

        let manager = EnvironmentCatalogManager(
            database: database,
            environmentsDirectory: rootDir.appendingPathComponent("env", isDirectory: true),
            assetValidator: { _ in true }
        )

        let sourceA = rootDir.appendingPathComponent("a.hdr")
        let sourceB = rootDir.appendingPathComponent("b.hdr")
        try Data("a".utf8).write(to: sourceA)
        try Data("b".utf8).write(to: sourceB)

        let first = try await manager.importEnvironment(from: sourceA)
        let second = try await manager.importEnvironment(from: sourceB)

        try await manager.activateAsset(id: first.id)
        try await manager.activateAsset(id: second.id)

        let assets = try await manager.fetchAssets()
        let previous = assets.first(where: { $0.id == first.id })
        let current = assets.first(where: { $0.id == second.id })
        #expect(previous?.isActive == false)
        #expect(current?.isActive == true)
    }

    @Test func resolvedAssetURLForExistingImportedFile() async throws {
        let (database, rootDir) = try await makeDatabase(named: "manager-resolved-existing.sqlite")
        defer { try? FileManager.default.removeItem(at: rootDir) }

        let envDir = rootDir.appendingPathComponent("env", isDirectory: true)
        try FileManager.default.createDirectory(at: envDir, withIntermediateDirectories: true)
        let manager = EnvironmentCatalogManager(database: database, environmentsDirectory: envDir)
        let file = envDir.appendingPathComponent("existing.hdr")
        try Data("hdr".utf8).write(to: file)

        let asset = EnvironmentAsset(id: "e", name: "E", sourceType: .imported, assetPath: file.path)
        let url = await manager.resolvedAssetURL(for: asset)
        #expect(url == file)
    }

    @Test func resolvedAssetURLForMissingImportedFileReturnsNil() async throws {
        let (database, rootDir) = try await makeDatabase(named: "manager-resolved-missing.sqlite")
        defer { try? FileManager.default.removeItem(at: rootDir) }

        let envDir = rootDir.appendingPathComponent("env", isDirectory: true)
        let manager = EnvironmentCatalogManager(database: database, environmentsDirectory: envDir)
        let missingPath = envDir.appendingPathComponent("missing.hdr").path
        let asset = EnvironmentAsset(id: "m", name: "M", sourceType: .imported, assetPath: missingPath)
        let url = await manager.resolvedAssetURL(for: asset)
        #expect(url == nil)
    }

    @Test func resolvedAssetURLForBundlePathReturnsNilForMissingResource() async throws {
        let (database, rootDir) = try await makeDatabase(named: "manager-resolved-bundle.sqlite")
        defer { try? FileManager.default.removeItem(at: rootDir) }

        let manager = EnvironmentCatalogManager(database: database)
        let asset = EnvironmentAsset(
            id: "b", name: "B", sourceType: .bundled, assetPath: "bundle://Fake/Resource.hdr"
        )
        let url = await manager.resolvedAssetURL(for: asset)
        #expect(url == nil)
    }

    @Test func resolvedAssetURLForEmptyBundlePathReturnsNil() async throws {
        let (database, rootDir) = try await makeDatabase(named: "manager-resolved-empty-bundle.sqlite")
        defer { try? FileManager.default.removeItem(at: rootDir) }

        let manager = EnvironmentCatalogManager(database: database)
        let asset = EnvironmentAsset(
            id: "eb", name: "EB", sourceType: .bundled, assetPath: "bundle:///"
        )
        let url = await manager.resolvedAssetURL(for: asset)
        #expect(url == nil)
    }

    @Test func resolvedAssetURLForBundlePathWithoutPrefixTreatsAsFilePath() async throws {
        let (database, rootDir) = try await makeDatabase(named: "manager-resolved-no-prefix.sqlite")
        defer { try? FileManager.default.removeItem(at: rootDir) }

        let envDir = rootDir.appendingPathComponent("env", isDirectory: true)
        try FileManager.default.createDirectory(at: envDir, withIntermediateDirectories: true)
        let manager = EnvironmentCatalogManager(database: database, environmentsDirectory: envDir)
        let file = envDir.appendingPathComponent("real.hdr")
        try Data("hdr".utf8).write(to: file)

        let asset = EnvironmentAsset(id: "np", name: "NP", sourceType: .imported, assetPath: file.path)
        let url = await manager.resolvedAssetURL(for: asset)
        #expect(url == file)
    }

    @Test func resolvedAssetURLRejectsImportedPathOutsideManagedDirectory() async throws {
        let (database, rootDir) = try await makeDatabase(named: "manager-resolved-external.sqlite")
        defer { try? FileManager.default.removeItem(at: rootDir) }

        let envDir = rootDir.appendingPathComponent("env", isDirectory: true)
        let manager = EnvironmentCatalogManager(database: database, environmentsDirectory: envDir)
        let file = rootDir.appendingPathComponent("external.hdr")
        try Data("hdr".utf8).write(to: file)

        let asset = EnvironmentAsset(id: "external", name: "External", sourceType: .imported, assetPath: file.path)
        let url = await manager.resolvedAssetURL(for: asset)
        #expect(url == nil)
    }

    @Test func immersiveSpaceIDForBundledWithUnknownExtension() async throws {
        let (database, _) = try await makeDatabase(named: "manager-space-bundled-unknown.sqlite")
        let manager = EnvironmentCatalogManager(database: database)
        let asset = EnvironmentAsset(id: "b1", name: "B1", sourceType: .bundled, assetPath: "some-asset")
        let spaceID = await manager.immersiveSpaceID(for: asset)
        #expect(spaceID == "customEnvironment")
    }

    @Test func immersiveSpaceIDForImportedHDR() async throws {
        let (database, _) = try await makeDatabase(named: "manager-space-hdr.sqlite")
        let manager = EnvironmentCatalogManager(database: database)
        let asset = EnvironmentAsset(id: "h1", name: "H1", sourceType: .imported, assetPath: "/tmp/sky.hdr")
        let spaceID = await manager.immersiveSpaceID(for: asset)
        #expect(spaceID == "hdriSkybox")
    }

    @Test func immersiveSpaceIDForImportedEXR() async throws {
        let (database, _) = try await makeDatabase(named: "manager-space-exr.sqlite")
        let manager = EnvironmentCatalogManager(database: database)
        let asset = EnvironmentAsset(id: "e1", name: "E1", sourceType: .imported, assetPath: "/tmp/sky.exr")
        let spaceID = await manager.immersiveSpaceID(for: asset)
        #expect(spaceID == "hdriSkybox")
    }

    @Test func immersiveSpaceIDForImportedUSDZ() async throws {
        let (database, _) = try await makeDatabase(named: "manager-space-usdz.sqlite")
        let manager = EnvironmentCatalogManager(database: database)
        let asset = EnvironmentAsset(id: "u1", name: "U1", sourceType: .imported, assetPath: "/tmp/model.usdz")
        let spaceID = await manager.immersiveSpaceID(for: asset)
        #expect(spaceID == "customEnvironment")
    }

    @Test func immersiveSpaceIDForImportedReality() async throws {
        let (database, _) = try await makeDatabase(named: "manager-space-reality.sqlite")
        let manager = EnvironmentCatalogManager(database: database)
        let asset = EnvironmentAsset(id: "r1", name: "R1", sourceType: .imported, assetPath: "/tmp/scene.reality")
        let spaceID = await manager.immersiveSpaceID(for: asset)
        #expect(spaceID == "customEnvironment")
    }

    @Test func immersiveSpaceIDForBundledHDR() async throws {
        let (database, _) = try await makeDatabase(named: "manager-space-bundled-hdr.sqlite")
        let manager = EnvironmentCatalogManager(database: database)
        let asset = EnvironmentAsset(id: "bh1", name: "BH1", sourceType: .bundled, assetPath: "bundle://sky.hdr")
        let spaceID = await manager.immersiveSpaceID(for: asset)
        #expect(spaceID == "hdriSkybox")
    }

    @Test func importEnvironmentAcceptsHDR() async throws {
        let (database, rootDir) = try await makeDatabase(named: "manager-import-hdr.sqlite")
        defer { try? FileManager.default.removeItem(at: rootDir) }

        let manager = EnvironmentCatalogManager(
            database: database,
            environmentsDirectory: rootDir.appendingPathComponent("env", isDirectory: true),
            assetValidator: { _ in true }
        )
        let source = rootDir.appendingPathComponent("cinema.hdr")
        try Data("fake-hdr".utf8).write(to: source)
        let imported = try await manager.importEnvironment(from: source)
        #expect(imported.sourceType == .imported)
        #expect(imported.assetPath.hasSuffix(".hdr"))
    }

    @Test func importEnvironmentAcceptsEXR() async throws {
        let (database, rootDir) = try await makeDatabase(named: "manager-import-exr.sqlite")
        defer { try? FileManager.default.removeItem(at: rootDir) }

        let manager = EnvironmentCatalogManager(
            database: database,
            environmentsDirectory: rootDir.appendingPathComponent("env", isDirectory: true),
            assetValidator: { _ in true }
        )
        let source = rootDir.appendingPathComponent("sky.exr")
        try Data("fake-exr".utf8).write(to: source)
        let imported = try await manager.importEnvironment(from: source)
        #expect(imported.assetPath.hasSuffix(".exr"))
    }

    @Test func importEnvironmentAcceptsUSDZ() async throws {
        let (database, rootDir) = try await makeDatabase(named: "manager-import-usdz.sqlite")
        defer { try? FileManager.default.removeItem(at: rootDir) }

        let manager = EnvironmentCatalogManager(
            database: database,
            environmentsDirectory: rootDir.appendingPathComponent("env", isDirectory: true),
            assetValidator: { _ in true }
        )
        let source = rootDir.appendingPathComponent("model.usdz")
        try Data("fake-usdz".utf8).write(to: source)
        let imported = try await manager.importEnvironment(from: source)
        #expect(imported.assetPath.hasSuffix(".usdz"))
    }

    @Test func importEnvironmentAcceptsReality() async throws {
        let (database, rootDir) = try await makeDatabase(named: "manager-import-reality.sqlite")
        defer { try? FileManager.default.removeItem(at: rootDir) }

        let manager = EnvironmentCatalogManager(
            database: database,
            environmentsDirectory: rootDir.appendingPathComponent("env", isDirectory: true),
            assetValidator: { _ in true }
        )
        let source = rootDir.appendingPathComponent("scene.reality")
        try Data("fake-reality".utf8).write(to: source)
        let imported = try await manager.importEnvironment(from: source)
        #expect(imported.assetPath.hasSuffix(".reality"))
    }

    @Test func importEnvironmentRejectsTXT() async throws {
        let (database, rootDir) = try await makeDatabase(named: "manager-import-txt.sqlite")
        defer { try? FileManager.default.removeItem(at: rootDir) }

        let manager = EnvironmentCatalogManager(
            database: database,
            environmentsDirectory: rootDir.appendingPathComponent("env", isDirectory: true)
        )
        let source = rootDir.appendingPathComponent("bad.txt")
        try Data("text".utf8).write(to: source)

        do {
            _ = try await manager.importEnvironment(from: source)
            Issue.record("Expected unsupported file type")
        } catch EnvironmentCatalogError.unsupportedFileType {
            #expect(Bool(true))
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }

    @Test func importEnvironmentRejectsMissingFile() async throws {
        let (database, rootDir) = try await makeDatabase(named: "manager-import-missing.sqlite")
        defer { try? FileManager.default.removeItem(at: rootDir) }

        let manager = EnvironmentCatalogManager(
            database: database,
            environmentsDirectory: rootDir.appendingPathComponent("env", isDirectory: true)
        )
        let missing = rootDir.appendingPathComponent("ghost.hdr")

        do {
            _ = try await manager.importEnvironment(from: missing)
            Issue.record("Expected missing file")
        } catch EnvironmentCatalogError.missingFile {
            #expect(Bool(true))
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }

    @Test func importEnvironmentUsesSourceFileNameAsDefault() async throws {
        let (database, rootDir) = try await makeDatabase(named: "manager-import-name.sqlite")
        defer { try? FileManager.default.removeItem(at: rootDir) }

        let manager = EnvironmentCatalogManager(
            database: database,
            environmentsDirectory: rootDir.appendingPathComponent("env", isDirectory: true),
            assetValidator: { _ in true }
        )
        let source = rootDir.appendingPathComponent("source.hdr")
        try Data("hdr".utf8).write(to: source)
        let imported = try await manager.importEnvironment(from: source)
        #expect(imported.name == "source")
    }

    @Test func yawOffsetPersistsThroughLocalImportRoundTrip() async throws {
        let (database, rootDir) = try await makeDatabase(named: "manager-yaw-local.sqlite")
        defer { try? FileManager.default.removeItem(at: rootDir) }

        let manager = EnvironmentCatalogManager(
            database: database,
            environmentsDirectory: rootDir.appendingPathComponent("env", isDirectory: true),
            assetValidator: { _ in true }
        )
        let source = rootDir.appendingPathComponent("yaw.hdr")
        try Data("hdr".utf8).write(to: source)
        let imported = try await manager.importEnvironment(from: source)

        let assets = try await manager.fetchAssets()
        let stored = assets.first(where: { $0.id == imported.id })
        #expect(stored?.hdriYawOffset == 0)
    }

    @Test func yawOffsetPersistsThroughRemoteImportRoundTrip() async throws {
        let (database, rootDir) = try await makeDatabase(named: "manager-yaw-remote.sqlite")
        defer { try? FileManager.default.removeItem(at: rootDir) }

        let manager = EnvironmentCatalogManager(
            database: database,
            environmentsDirectory: rootDir.appendingPathComponent("env", isDirectory: true),
            assetValidator: { _ in true },
            remoteDataFetcher: { url in
                let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
                return (Data("remote-hdr".utf8), response)
            }
        )

        let imported = try await manager.importEnvironment(
            fromRemote: URL(string: "https://example.com/remote.hdr")!,
            preferredName: "Remote",
            hdriYawOffset: 90.0
        )

        let assets = try await manager.fetchAssets()
        let stored = assets.first(where: { $0.id == imported.id })
        #expect(stored?.hdriYawOffset == 90.0)
    }

    @Test func curatedPresetYawOffsetPersistsThroughImport() async throws {
        let (database, rootDir) = try await makeDatabase(named: "manager-yaw-curated.sqlite")
        defer { try? FileManager.default.removeItem(at: rootDir) }

        let manager = EnvironmentCatalogManager(
            database: database,
            environmentsDirectory: rootDir.appendingPathComponent("env", isDirectory: true),
            assetValidator: { _ in true },
            remoteDataFetcher: { url in
                let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
                return (Data("preset-hdr".utf8), response)
            }
        )

        let preset = CuratedEnvironmentPreset(
            id: "curated-yaw",
            name: "Curated Yaw",
            description: "Test",
            provider: .polyHaven,
            downloadURL: URL(string: "https://example.com/curated.hdr")!,
            sourceAttributionURL: "https://example.com",
            licenseName: "CC0",
            defaultHdriYawOffset: -45.0
        )

        let imported = try await manager.importCuratedPreset(preset)
        let assets = try await manager.fetchAssets()
        let stored = assets.first(where: { $0.id == imported.id })
        #expect(stored?.hdriYawOffset == -45.0)
    }

    @Test func curatedPresetEnvironmentTagPersistsCanonicallyThroughImportAndIsMatchable() async throws {
        let (database, rootDir) = try await makeDatabase(named: "manager-tag-curated.sqlite")
        defer { try? FileManager.default.removeItem(at: rootDir) }

        let manager = EnvironmentCatalogManager(
            database: database,
            environmentsDirectory: rootDir.appendingPathComponent("env", isDirectory: true),
            assetValidator: { _ in true },
            remoteDataFetcher: { url in
                let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
                return (Data("preset-hdr".utf8), response)
            }
        )

        let preset = CuratedEnvironmentPreset(
            id: "curated-tagged",
            name: "Curated Tagged",
            description: "Test",
            provider: .polyHaven,
            downloadURL: URL(string: "https://example.com/curated-tagged.hdr")!,
            sourceAttributionURL: "https://example.com",
            licenseName: "CC0",
            defaultEnvironmentTag: " Sci   Fi "
        )

        let imported = try await manager.importCuratedPreset(preset)
        let stored = try await manager.fetchAssets().first { $0.id == imported.id }
        #expect(stored?.environmentTag == "scifi")
        // Genre auto-match must resolve the installed preset from either stored
        // canonical tags or human genre-name aliases.
        #expect(try await manager.asset(matchingTag: "Science Fiction")?.id == imported.id)
    }

    @Test func curatedRemotePresetsCarryCinemaTag() {
        // Online cinema presets must be tagged so installing one wires up genre auto-match.
        for preset in EnvironmentCatalogManager.onlinePresets {
            #expect(preset.defaultEnvironmentTag == GenreEnvironmentSuggestionPolicy.neutralDefault.matchKey)
        }
    }

    @Test func deleteAssetRemovesImportedFileAndDatabaseEntry() async throws {
        let (database, rootDir) = try await makeDatabase(named: "manager-delete.sqlite")
        defer { try? FileManager.default.removeItem(at: rootDir) }

        let manager = EnvironmentCatalogManager(
            database: database,
            environmentsDirectory: rootDir.appendingPathComponent("env", isDirectory: true),
            assetValidator: { _ in true }
        )
        let source = rootDir.appendingPathComponent("delete.hdr")
        try Data("hdr".utf8).write(to: source)
        let imported = try await manager.importEnvironment(from: source)
        #expect(FileManager.default.fileExists(atPath: imported.assetPath))

        try await manager.deleteAsset(id: imported.id)
        #expect(!FileManager.default.fileExists(atPath: imported.assetPath))
        #expect(try await manager.fetchAssets().isEmpty)
    }

    @Test func deleteAssetDoesNotCrashForMissingID() async throws {
        let (database, rootDir) = try await makeDatabase(named: "manager-delete-missing.sqlite")
        defer { try? FileManager.default.removeItem(at: rootDir) }

        let manager = EnvironmentCatalogManager(
            database: database,
            environmentsDirectory: rootDir.appendingPathComponent("env", isDirectory: true)
        )
        try await manager.deleteAsset(id: "nonexistent")
        #expect(try await manager.fetchAssets().isEmpty)
    }

    @Test func deleteAssetDoesNotRemoveExternalImportedPath() async throws {
        let (database, rootDir) = try await makeDatabase(named: "manager-delete-external.sqlite")
        defer { try? FileManager.default.removeItem(at: rootDir) }

        let envDir = rootDir.appendingPathComponent("env", isDirectory: true)
        let externalFile = rootDir.appendingPathComponent("external.hdr")
        try Data("do-not-delete".utf8).write(to: externalFile)
        let asset = EnvironmentAsset(
            id: "external",
            name: "External",
            sourceType: .imported,
            assetPath: externalFile.path
        )
        try await database.saveEnvironmentAsset(asset)

        let manager = EnvironmentCatalogManager(database: database, environmentsDirectory: envDir)
        try await manager.deleteAsset(id: asset.id)

        #expect(FileManager.default.fileExists(atPath: externalFile.path))
        #expect(try await manager.fetchAssets().isEmpty)
    }

    @Test func fetchAssetsReturnsEmptyInitially() async throws {
        let (database, rootDir) = try await makeDatabase(named: "manager-fetch-empty.sqlite")
        defer { try? FileManager.default.removeItem(at: rootDir) }

        let manager = EnvironmentCatalogManager(
            database: database,
            environmentsDirectory: rootDir.appendingPathComponent("env", isDirectory: true)
        )
        let assets = try await manager.fetchAssets()
        #expect(assets.isEmpty)
    }

    @Test func bootstrapRemovesStaleBundledAssets() async throws {
        let (database, rootDir) = try await makeDatabase(named: "manager-bootstrap-stale.sqlite")
        defer { try? FileManager.default.removeItem(at: rootDir) }

        let stale = EnvironmentAsset(
            id: "old-bundled",
            name: "Old",
            sourceType: .bundled,
            assetPath: "/old",
            isActive: false
        )
        try await database.saveEnvironmentAsset(stale)

        let manager = EnvironmentCatalogManager(
            database: database,
            environmentsDirectory: rootDir.appendingPathComponent("env", isDirectory: true)
        )
        try await manager.bootstrapCuratedAssets()

        let assets = try await manager.fetchAssets()
        #expect(!assets.contains(where: { $0.id == "old-bundled" }))
    }

    @Test func bootstrapPrunesOrphanedImportedAssets() async throws {
        let (database, rootDir) = try await makeDatabase(named: "manager-bootstrap-orphan.sqlite")
        defer { try? FileManager.default.removeItem(at: rootDir) }

        let orphan = EnvironmentAsset(
            id: "orphan",
            name: "Orphan",
            sourceType: .imported,
            assetPath: rootDir.appendingPathComponent("deleted.hdr").path,
            isActive: false
        )
        try await database.saveEnvironmentAsset(orphan)

        let manager = EnvironmentCatalogManager(
            database: database,
            environmentsDirectory: rootDir.appendingPathComponent("env", isDirectory: true)
        )
        try await manager.bootstrapCuratedAssets()

        let assets = try await manager.fetchAssets()
        #expect(!assets.contains(where: { $0.id == "orphan" }))
    }

    @Test func bootstrapPrunesActiveOrphanAndClearsPreferredEnvironment() async throws {
        let (database, rootDir) = try await makeDatabase(named: "manager-bootstrap-active-orphan.sqlite")
        defer { try? FileManager.default.removeItem(at: rootDir) }

        let orphan = EnvironmentAsset(
            id: "active-orphan",
            name: "Deleted Panorama",
            sourceType: .imported,
            assetPath: rootDir.appendingPathComponent("missing.hdr").path,
            isActive: true
        )
        try await database.saveEnvironmentAsset(orphan)
        try await database.setSetting(key: SettingsKeys.preferredEnvironment, value: orphan.id)
        try await database.setSetting(key: SettingsKeys.activeEnvironmentSelectionCleared, value: nil)

        let manager = EnvironmentCatalogManager(
            database: database,
            environmentsDirectory: rootDir.appendingPathComponent("env", isDirectory: true)
        )

        try await manager.bootstrapCuratedAssets()

        let assets = try await manager.fetchAssets()
        let active = try await manager.activeAsset()
        let preferred = try await database.getSetting(key: SettingsKeys.preferredEnvironment)
        let cleared = try await database.getSetting(key: SettingsKeys.activeEnvironmentSelectionCleared)

        #expect(!assets.contains(where: { $0.id == orphan.id }))
        #expect(assets.contains(where: { $0.id == EnvironmentCatalogManager.bundledSkyDomeID }))
        #expect(active == nil)
        #expect(preferred == nil)
        #expect(cleared == "1")
    }

    @Test func fetchAssetsPrunesOrphanedImportedAssetsWithoutBootstrap() async throws {
        let (database, rootDir) = try await makeDatabase(named: "manager-fetch-orphan.sqlite")
        defer { try? FileManager.default.removeItem(at: rootDir) }

        let envDir = rootDir.appendingPathComponent("env", isDirectory: true)
        let orphan = EnvironmentAsset(
            id: "fetch-orphan",
            name: "Deleted Panorama",
            sourceType: .imported,
            assetPath: envDir.appendingPathComponent("deleted.hdr").path,
            isActive: false
        )
        try await database.saveEnvironmentAsset(orphan)

        let manager = EnvironmentCatalogManager(database: database, environmentsDirectory: envDir)
        let assets = try await manager.fetchAssets()
        let stored = try await database.fetchEnvironmentAssets()

        #expect(!assets.contains(where: { $0.id == orphan.id }))
        #expect(!stored.contains(where: { $0.id == orphan.id }))
    }

    @Test func activeAssetPrunesActiveOrphanAndClearsPreferredEnvironmentWithoutBootstrap() async throws {
        let (database, rootDir) = try await makeDatabase(named: "manager-active-orphan.sqlite")
        defer { try? FileManager.default.removeItem(at: rootDir) }

        let envDir = rootDir.appendingPathComponent("env", isDirectory: true)
        let orphan = EnvironmentAsset(
            id: "active-fetch-orphan",
            name: "Deleted Active Panorama",
            sourceType: .imported,
            assetPath: envDir.appendingPathComponent("missing.hdr").path,
            isActive: true
        )
        try await database.saveEnvironmentAsset(orphan)
        try await database.setSetting(key: SettingsKeys.preferredEnvironment, value: orphan.id)
        try await database.setSetting(key: SettingsKeys.activeEnvironmentSelectionCleared, value: nil)

        let manager = EnvironmentCatalogManager(database: database, environmentsDirectory: envDir)

        let active = try await manager.activeAsset()
        let assets = try await manager.fetchAssets()
        let preferred = try await database.getSetting(key: SettingsKeys.preferredEnvironment)
        let cleared = try await database.getSetting(key: SettingsKeys.activeEnvironmentSelectionCleared)

        #expect(active == nil)
        #expect(!assets.contains(where: { $0.id == orphan.id }))
        #expect(preferred == nil)
        #expect(cleared == "1")
    }

    @Test func missingResolvedAssetURLDoesNotCrash() async throws {
        let (database, rootDir) = try await makeDatabase(named: "manager-missing-url.sqlite")
        defer { try? FileManager.default.removeItem(at: rootDir) }

        let manager = EnvironmentCatalogManager(database: database)
        let asset = EnvironmentAsset(
            id: "missing",
            name: "Missing",
            sourceType: .imported,
            assetPath: "/this/does/not/exist/file.hdr"
        )
        let url = await manager.resolvedAssetURL(for: asset)
        #expect(url == nil)
    }

    @Test func environmentCatalogErrorDescriptions() {
        #expect(EnvironmentCatalogError.unsupportedFileType.errorDescription?.contains("Unsupported") == true)
        #expect(EnvironmentCatalogError.missingFile.errorDescription?.contains("could not be read") == true)
        #expect(EnvironmentCatalogError.invalidAsset.errorDescription?.contains("could not be loaded") == true)
        #expect(EnvironmentCatalogError.downloadFailed("network").errorDescription?.contains("network") == true)
    }

    @Test func resolveHdriYawOffsetWithNilReturnsZero() {
        #expect(EnvironmentCatalogManager.resolveHdriYawOffset(from: nil) == 0)
    }

    @Test func resolveHdriYawOffsetWithValueReturnsValue() {
        #expect(EnvironmentCatalogManager.resolveHdriYawOffset(from: 33.3) == 33.3)
    }

    // MARK: - Validation refactor behavior preservation + broadened skybox routing

    @Test func immersiveSpaceIDForImportedPNGRoutesToHDRISkybox() async throws {
        let (database, _) = try await makeDatabase(named: "manager-space-png.sqlite")
        let manager = EnvironmentCatalogManager(database: database)
        let asset = EnvironmentAsset(id: "p1", name: "P1", sourceType: .imported, assetPath: "/tmp/sky.png")
        let spaceID = await manager.immersiveSpaceID(for: asset)
        #expect(spaceID == "hdriSkybox")
    }

    @Test func immersiveSpaceIDForImportedJPGRoutesToHDRISkybox() async throws {
        let (database, _) = try await makeDatabase(named: "manager-space-jpg.sqlite")
        let manager = EnvironmentCatalogManager(database: database)
        let asset = EnvironmentAsset(id: "j1", name: "J1", sourceType: .imported, assetPath: "/tmp/sky.jpg")
        let spaceID = await manager.immersiveSpaceID(for: asset)
        #expect(spaceID == "hdriSkybox")
    }

    @Test func importEnvironmentAcceptsPNGSkybox() async throws {
        let (database, rootDir) = try await makeDatabase(named: "manager-import-png.sqlite")
        defer { try? FileManager.default.removeItem(at: rootDir) }

        let manager = EnvironmentCatalogManager(
            database: database,
            environmentsDirectory: rootDir.appendingPathComponent("env", isDirectory: true),
            assetValidator: { _ in true }
        )
        let source = rootDir.appendingPathComponent("pano.png")
        try Data("fake-png".utf8).write(to: source)
        let imported = try await manager.importEnvironment(from: source)
        #expect(imported.assetPath.hasSuffix(".png"))
    }

    @Test func importEnvironmentNormalizesUppercasePanoramaExtensionAndYawOffset() async throws {
        let (database, rootDir) = try await makeDatabase(named: "manager-import-uppercase-png.sqlite")
        defer { try? FileManager.default.removeItem(at: rootDir) }

        let manager = EnvironmentCatalogManager(
            database: database,
            environmentsDirectory: rootDir.appendingPathComponent("env", isDirectory: true),
            assetValidator: { _ in true }
        )
        let source = rootDir.appendingPathComponent("PANO.PNG")
        try Data("fake-png".utf8).write(to: source)

        let imported = try await manager.importEnvironment(from: source)

        #expect(imported.assetPath.hasSuffix(".png"))
        #expect(imported.hdriYawOffset == 0)
    }

    @Test func importEnvironmentStillRejectsTXTAfterRefactor() async throws {
        let (database, rootDir) = try await makeDatabase(named: "manager-import-txt-refactor.sqlite")
        defer { try? FileManager.default.removeItem(at: rootDir) }

        let manager = EnvironmentCatalogManager(
            database: database,
            environmentsDirectory: rootDir.appendingPathComponent("env", isDirectory: true)
        )
        let source = rootDir.appendingPathComponent("bad.txt")
        try Data("text".utf8).write(to: source)

        do {
            _ = try await manager.importEnvironment(from: source)
            Issue.record("Expected unsupported file type")
        } catch EnvironmentCatalogError.unsupportedFileType {
            #expect(Bool(true))
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }

    @Test func environmentTagPersistsThroughDatabaseRoundTrip() async throws {
        let (database, rootDir) = try await makeDatabase(named: "manager-tag-roundtrip.sqlite")
        defer { try? FileManager.default.removeItem(at: rootDir) }

        let asset = EnvironmentAsset(
            id: "tagged-asset",
            name: "Tagged",
            sourceType: .imported,
            assetPath: "/tmp/tagged.hdr",
            environmentTag: "scifi"
        )
        try await database.saveEnvironmentAsset(asset)
        let fetched = try await database.fetchEnvironmentAssets()
        #expect(fetched.first?.environmentTag == "scifi")
    }

    @Test func assetMatchingTagFindsTaggedAssetAndRejectsBlank() async throws {
        let (database, rootDir) = try await makeDatabase(named: "manager-tag-match.sqlite")
        defer { try? FileManager.default.removeItem(at: rootDir) }

        let envDir = rootDir.appendingPathComponent("env", isDirectory: true)
        try FileManager.default.createDirectory(at: envDir, withIntermediateDirectories: true)
        let horrorURL = envDir.appendingPathComponent("h.hdr")
        let untaggedURL = envDir.appendingPathComponent("u.hdr")
        try Data("h".utf8).write(to: horrorURL)
        try Data("u".utf8).write(to: untaggedURL)

        let manager = EnvironmentCatalogManager(database: database, environmentsDirectory: envDir)
        try await database.saveEnvironmentAsset(
            EnvironmentAsset(
                id: "t1",
                name: "Horror Env",
                sourceType: .imported,
                assetPath: horrorURL.path,
                environmentTag: "horror"
            )
        )
        try await database.saveEnvironmentAsset(
            EnvironmentAsset(
                id: "t2",
                name: "Untagged",
                sourceType: .imported,
                assetPath: untaggedURL.path
            )
        )

        #expect(try await manager.asset(matchingTag: "HORROR")?.id == "t1")
        #expect(try await manager.asset(matchingTag: "scifi") == nil)
        #expect(try await manager.asset(matchingTag: "") == nil)
    }

    @MainActor
    @Test func activateAssetPostsEnvironmentsDidChangeNotification() async throws {
        let (database, rootDir) = try await makeDatabase(named: "manager-notification.sqlite")
        defer { try? FileManager.default.removeItem(at: rootDir) }

        let manager = EnvironmentCatalogManager(
            database: database,
            environmentsDirectory: rootDir.appendingPathComponent("env", isDirectory: true),
            assetValidator: { _ in true }
        )

        let source = rootDir.appendingPathComponent("note.hdr")
        try Data("hdr".utf8).write(to: source)
        let imported = try await manager.importEnvironment(from: source)

        var received = false
        let token = NotificationCenter.default.addObserver(
            forName: .environmentsDidChange,
            object: nil,
            queue: .main
        ) { _ in
            received = true
        }
        defer { NotificationCenter.default.removeObserver(token) }

        try await manager.activateAsset(id: imported.id)

        // Give the internal Task a moment to post.
        try await Task.sleep(nanoseconds: 100_000_000)
        #expect(received == true)
    }

    @MainActor
    @Test func clearActiveAssetPostsEnvironmentsDidChangeNotification() async throws {
        let (database, rootDir) = try await makeDatabase(named: "manager-clear-notification.sqlite")
        defer { try? FileManager.default.removeItem(at: rootDir) }

        let manager = EnvironmentCatalogManager(
            database: database,
            environmentsDirectory: rootDir.appendingPathComponent("env", isDirectory: true)
        )

        var received = false
        let token = NotificationCenter.default.addObserver(
            forName: .environmentsDidChange,
            object: nil,
            queue: .main
        ) { _ in
            received = true
        }
        defer { NotificationCenter.default.removeObserver(token) }

        try await manager.clearActiveAsset()

        // Give the internal Task a moment to post.
        try await Task.sleep(nanoseconds: 100_000_000)
        #expect(received == true)
    }
}
