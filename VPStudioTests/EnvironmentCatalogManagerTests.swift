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

    @Test func bootstrapCuratedAssetsWithEmptyDefaultsLeavesDatabaseEmpty() async throws {
        let (database, rootDir) = try await makeDatabase(named: "manager-bootstrap-empty.sqlite")
        defer { try? FileManager.default.removeItem(at: rootDir) }

        let manager = EnvironmentCatalogManager(
            database: database,
            environmentsDirectory: rootDir.appendingPathComponent("env", isDirectory: true)
        )
        try await manager.bootstrapCuratedAssets()

        let assets = try await manager.fetchAssets()
        #expect(assets.isEmpty)
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

        let manager = EnvironmentCatalogManager(database: database)
        let file = rootDir.appendingPathComponent("existing.hdr")
        try Data("hdr".utf8).write(to: file)

        let asset = EnvironmentAsset(id: "e", name: "E", sourceType: .imported, assetPath: file.path)
        let url = await manager.resolvedAssetURL(for: asset)
        #expect(url == file)
    }

    @Test func resolvedAssetURLForMissingImportedFileReturnsNil() async throws {
        let (database, rootDir) = try await makeDatabase(named: "manager-resolved-missing.sqlite")
        defer { try? FileManager.default.removeItem(at: rootDir) }

        let manager = EnvironmentCatalogManager(database: database)
        let missingPath = rootDir.appendingPathComponent("missing.hdr").path
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

        let manager = EnvironmentCatalogManager(database: database)
        let file = rootDir.appendingPathComponent("real.hdr")
        try Data("hdr".utf8).write(to: file)

        let asset = EnvironmentAsset(id: "np", name: "NP", sourceType: .imported, assetPath: file.path)
        let url = await manager.resolvedAssetURL(for: asset)
        #expect(url == file)
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
}
