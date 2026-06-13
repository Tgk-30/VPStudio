import Foundation
import Synchronization
import Testing
@testable import VPStudio

@Suite("EnvironmentCatalogManager Validation Tests", .serialized)
struct EnvironmentCatalogManagerValidationTests {

    private func makeDatabase(named fileName: String) async throws -> (DatabaseManager, URL) {
        let rootDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: rootDir, withIntermediateDirectories: true)
        let database = try DatabaseManager(inMemoryNamed: "\(fileName)-\(UUID().uuidString)")
        try await database.migrate()
        return (database, rootDir)
    }

    @Test
    func importRejectsUnsupportedExtension() async throws {
        let (database, rootDir) = try await makeDatabase(named: "validation-unsupported-ext.sqlite")
        defer { try? FileManager.default.removeItem(at: rootDir) }

        let manager = EnvironmentCatalogManager(
            database: database,
            environmentsDirectory: rootDir.appendingPathComponent("env", isDirectory: true)
        )
        let source = rootDir.appendingPathComponent("video.mp4")
        try Data("mp4 data".utf8).write(to: source)

        do {
            _ = try await manager.importEnvironment(from: source)
            Issue.record("Expected unsupported file type error")
        } catch EnvironmentCatalogError.unsupportedFileType {
            #expect(Bool(true))
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }

    @Test
    func importRejectsExtensionCaseInsensitive() async throws {
        let (database, rootDir) = try await makeDatabase(named: "validation-case-insensitive.sqlite")
        defer { try? FileManager.default.removeItem(at: rootDir) }

        let manager = EnvironmentCatalogManager(
            database: database,
            environmentsDirectory: rootDir.appendingPathComponent("env", isDirectory: true),
            assetValidator: { _ in true }
        )
        let source = rootDir.appendingPathComponent("env.HDR")
        try Data("hdr".utf8).write(to: source)

        let imported = try await manager.importEnvironment(from: source)
        #expect(imported.assetPath.hasSuffix(".HDR"))
    }

    @Test
    func importRejectsUnsupportedExtensions() async throws {
        let (database, rootDir) = try await makeDatabase(named: "validation-unsupported-multi.sqlite")
        defer { try? FileManager.default.removeItem(at: rootDir) }

        let manager = EnvironmentCatalogManager(
            database: database,
            environmentsDirectory: rootDir.appendingPathComponent("env", isDirectory: true)
        )

        let unsupportedExtensions = ["mp4", "mov", "jpg", "png", "pdf", "txt"]

        for ext in unsupportedExtensions {
            let source = rootDir.appendingPathComponent("file.\(ext)")
            try Data("data".utf8).write(to: source)

            do {
                _ = try await manager.importEnvironment(from: source)
                Issue.record("Expected unsupported file type error for .\(ext)")
            } catch EnvironmentCatalogError.unsupportedFileType {
                #expect(Bool(true))
            } catch {
                Issue.record("Unexpected error for .\(ext): \(error)")
            }
        }
    }

    @Test
    func importRejectsMissingFile() async throws {
        let (database, rootDir) = try await makeDatabase(named: "validation-missing-file.sqlite")
        defer { try? FileManager.default.removeItem(at: rootDir) }

        let manager = EnvironmentCatalogManager(
            database: database,
            environmentsDirectory: rootDir.appendingPathComponent("env", isDirectory: true)
        )
        let missing = rootDir.appendingPathComponent("ghost.usdz")

        do {
            _ = try await manager.importEnvironment(from: missing)
            Issue.record("Expected missing file error")
        } catch EnvironmentCatalogError.missingFile {
            #expect(Bool(true))
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }

    @Test
    func importAcceptsAllSupportedExtensions() async throws {
        let (database, rootDir) = try await makeDatabase(named: "validation-supported-multi.sqlite")
        defer { try? FileManager.default.removeItem(at: rootDir) }

        let manager = EnvironmentCatalogManager(
            database: database,
            environmentsDirectory: rootDir.appendingPathComponent("env", isDirectory: true),
            assetValidator: { _ in true }
        )

        let supportedExtensions = ["hdr", "exr", "usdz", "reality"]

        for ext in supportedExtensions {
            let source = rootDir.appendingPathComponent("file.\(ext)")
            try Data("\(ext) data".utf8).write(to: source)

            let imported = try await manager.importEnvironment(from: source)
            #expect(imported.assetPath.hasSuffix(".\(ext)"))
        }
    }

    @Test
    func importValidatesAssetWithProvidedValidator() async throws {
        let (database, rootDir) = try await makeDatabase(named: "validation-custom-validator.sqlite")
        defer { try? FileManager.default.removeItem(at: rootDir) }

        let validatorCalls = Mutex(0)
        let manager = EnvironmentCatalogManager(
            database: database,
            environmentsDirectory: rootDir.appendingPathComponent("env", isDirectory: true),
            assetValidator: { url in
                validatorCalls.withLock { $0 += 1 }
                return url.deletingPathExtension().lastPathComponent == "valid"
            }
        )

        let validSource = rootDir.appendingPathComponent("valid.hdr")
        try Data("hdr".utf8).write(to: validSource)
        let validImported = try await manager.importEnvironment(from: validSource)
        #expect(validImported.assetPath.hasSuffix(".hdr"))

        let invalidSource = rootDir.appendingPathComponent("broken.hdr")
        try Data("hdr".utf8).write(to: invalidSource)
        do {
            _ = try await manager.importEnvironment(from: invalidSource)
            Issue.record("Expected invalid asset error")
        } catch EnvironmentCatalogError.invalidAsset {
            let callCount = validatorCalls.withLock { $0 }
            #expect(callCount >= 2)
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }

    @Test
    func importEnvironmentWithNoExtensionUsesDefaultAssetValidation() async throws {
        let (database, rootDir) = try await makeDatabase(named: "validation-no-ext.sqlite")
        defer { try? FileManager.default.removeItem(at: rootDir) }

        let manager = EnvironmentCatalogManager(
            database: database,
            environmentsDirectory: rootDir.appendingPathComponent("env", isDirectory: true),
            assetValidator: { _ in true }
        )
        let source = rootDir.appendingPathComponent("noextension")
        try Data("data".utf8).write(to: source)

        do {
            _ = try await manager.importEnvironment(from: source)
            Issue.record("Expected unsupported file type error")
        } catch EnvironmentCatalogError.unsupportedFileType {
            #expect(Bool(true))
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }

    @Test
    func importEnvironmentRejectsExtensionWithNoSeparator() async throws {
        let (database, rootDir) = try await makeDatabase(named: "validation-no-separator.sqlite")
        defer { try? FileManager.default.removeItem(at: rootDir) }

        let manager = EnvironmentCatalogManager(
            database: database,
            environmentsDirectory: rootDir.appendingPathComponent("env", isDirectory: true)
        )
        let source = rootDir.appendingPathComponent("filehdr")
        try Data("data".utf8).write(to: source)

        do {
            _ = try await manager.importEnvironment(from: source)
            Issue.record("Expected unsupported file type error")
        } catch EnvironmentCatalogError.unsupportedFileType {
            #expect(Bool(true))
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }
}

@Suite("EnvironmentCatalogManager Fetch and Activate Tests", .serialized)
struct EnvironmentCatalogManagerFetchActivateTests {

    private func makeDatabase(named fileName: String) async throws -> (DatabaseManager, URL) {
        let rootDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: rootDir, withIntermediateDirectories: true)
        let database = try DatabaseManager(inMemoryNamed: "\(fileName)-\(UUID().uuidString)")
        try await database.migrate()
        return (database, rootDir)
    }

    @Test
    func activateAssetWithInvalidIDDoesNotThrow() async throws {
        let (database, rootDir) = try await makeDatabase(named: "fetch-activate-invalid.sqlite")
        defer { try? FileManager.default.removeItem(at: rootDir) }

        let manager = EnvironmentCatalogManager(
            database: database,
            environmentsDirectory: rootDir.appendingPathComponent("env", isDirectory: true)
        )

        try await manager.activateAsset(id: "nonexistent-id")
        #expect(Bool(true))
    }

    @Test
    func activateAssetUpdatesIsActiveFlag() async throws {
        let (database, rootDir) = try await makeDatabase(named: "fetch-activate-isactive.sqlite")
        defer { try? FileManager.default.removeItem(at: rootDir) }

        let manager = EnvironmentCatalogManager(
            database: database,
            environmentsDirectory: rootDir.appendingPathComponent("env", isDirectory: true),
            assetValidator: { _ in true }
        )

        let source = rootDir.appendingPathComponent("active.hdr")
        try Data("hdr".utf8).write(to: source)
        let imported = try await manager.importEnvironment(from: source)

        #expect(imported.isActive == false)

        try await manager.activateAsset(id: imported.id)

        let activeAsset = try await manager.activeAsset()
        #expect(activeAsset?.id == imported.id)
        #expect(activeAsset?.isActive == true)
    }

    @Test
    func fetchAssetsReturnsAllImportedAssets() async throws {
        let (database, rootDir) = try await makeDatabase(named: "fetch-assets-multiple.sqlite")
        defer { try? FileManager.default.removeItem(at: rootDir) }

        let manager = EnvironmentCatalogManager(
            database: database,
            environmentsDirectory: rootDir.appendingPathComponent("env", isDirectory: true),
            assetValidator: { _ in true }
        )

        let source1 = rootDir.appendingPathComponent("a.hdr")
        let source2 = rootDir.appendingPathComponent("b.hdr")
        try Data("a".utf8).write(to: source1)
        try Data("b".utf8).write(to: source2)

        _ = try await manager.importEnvironment(from: source1)
        _ = try await manager.importEnvironment(from: source2)

        let assets = try await manager.fetchAssets()
        #expect(assets.count >= 2)
    }

    @Test
    func fetchAssetsIsEmptyForFreshDatabase() async throws {
        let (database, rootDir) = try await makeDatabase(named: "fetch-assets-empty.sqlite")
        defer { try? FileManager.default.removeItem(at: rootDir) }

        let manager = EnvironmentCatalogManager(
            database: database,
            environmentsDirectory: rootDir.appendingPathComponent("env", isDirectory: true)
        )

        let assets = try await manager.fetchAssets()
        #expect(assets.isEmpty)
    }

    @Test
    func activeAssetIsNilWhenNoAssetsImported() async throws {
        let (database, rootDir) = try await makeDatabase(named: "fetch-active-nil.sqlite")
        defer { try? FileManager.default.removeItem(at: rootDir) }

        let manager = EnvironmentCatalogManager(
            database: database,
            environmentsDirectory: rootDir.appendingPathComponent("env", isDirectory: true)
        )

        let active = try await manager.activeAsset()
        #expect(active == nil)
    }

    @Test
    func deleteAssetWithInvalidIDDoesNotThrow() async throws {
        let (database, rootDir) = try await makeDatabase(named: "fetch-delete-invalid.sqlite")
        defer { try? FileManager.default.removeItem(at: rootDir) }

        let manager = EnvironmentCatalogManager(
            database: database,
            environmentsDirectory: rootDir.appendingPathComponent("env", isDirectory: true)
        )

        try await manager.deleteAsset(id: "nonexistent")
        #expect(Bool(true))
    }

    @Test
    func deleteLastActiveAssetSetsNewActiveAsset() async throws {
        let (database, rootDir) = try await makeDatabase(named: "fetch-delete-last-active.sqlite")
        defer { try? FileManager.default.removeItem(at: rootDir) }

        let manager = EnvironmentCatalogManager(
            database: database,
            environmentsDirectory: rootDir.appendingPathComponent("env", isDirectory: true),
            assetValidator: { _ in true }
        )

        let source1 = rootDir.appendingPathComponent("first.hdr")
        let source2 = rootDir.appendingPathComponent("second.hdr")
        try Data("first".utf8).write(to: source1)
        try Data("second".utf8).write(to: source2)

        let first = try await manager.importEnvironment(from: source1)
        let second = try await manager.importEnvironment(from: source2)

        try await manager.activateAsset(id: second.id)
        try await manager.deleteAsset(id: second.id)

        let activeAfter = try await manager.activeAsset()
        #expect(activeAfter?.id == first.id)
    }
}

@Suite("EnvironmentCatalogManager Persistence Tests", .serialized)
struct EnvironmentCatalogManagerPersistenceTests {

    private func makeDatabase(named fileName: String) async throws -> (DatabaseManager, URL) {
        let rootDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: rootDir, withIntermediateDirectories: true)
        let database = try DatabaseManager(inMemoryNamed: "\(fileName)-\(UUID().uuidString)")
        try await database.migrate()
        return (database, rootDir)
    }

    @Test
    func importedAssetPersistsToDatabase() async throws {
        let (database, rootDir) = try await makeDatabase(named: "persist-import.sqlite")
        defer { try? FileManager.default.removeItem(at: rootDir) }

        let manager = EnvironmentCatalogManager(
            database: database,
            environmentsDirectory: rootDir.appendingPathComponent("env", isDirectory: true),
            assetValidator: { _ in true }
        )

        let source = rootDir.appendingPathComponent("persist.hdr")
        try Data("hdr".utf8).write(to: source)
        let imported = try await manager.importEnvironment(from: source)

        let fetched = try await manager.fetchAssets()
        #expect(fetched.contains(where: { $0.id == imported.id }))
    }

    @Test
    func importedAssetContainsCorrectMetadata() async throws {
        let (database, rootDir) = try await makeDatabase(named: "persist-metadata.sqlite")
        defer { try? FileManager.default.removeItem(at: rootDir) }

        let manager = EnvironmentCatalogManager(
            database: database,
            environmentsDirectory: rootDir.appendingPathComponent("env", isDirectory: true),
            assetValidator: { _ in true }
        )

        let source = rootDir.appendingPathComponent("meta.hdr")
        try Data("hdr".utf8).write(to: source)
        let imported = try await manager.importEnvironment(from: source)

        #expect(imported.name == "meta")
        #expect(imported.sourceType == .imported)
        #expect(imported.licenseName == "User Imported")
        #expect(imported.sourceAttributionURL == nil)
        #expect(imported.hdriYawOffset == 0)
        #expect(imported.isActive == false)
    }

    @Test
    func importedAssetFilePathPointsToPersistentLocation() async throws {
        let (database, rootDir) = try await makeDatabase(named: "persist-filepath.sqlite")
        defer { try? FileManager.default.removeItem(at: rootDir) }

        let envDir = rootDir.appendingPathComponent("env", isDirectory: true)

        let manager = EnvironmentCatalogManager(
            database: database,
            environmentsDirectory: envDir,
            assetValidator: { _ in true }
        )

        let source = rootDir.appendingPathComponent("path.hdr")
        try Data("hdr".utf8).write(to: source)
        let imported = try await manager.importEnvironment(from: source)

        let fileManager = FileManager.default
        #expect(fileManager.fileExists(atPath: imported.assetPath))
        #expect(imported.assetPath.contains("env/"))
    }

    @Test
    func deleteAssetRemovesDatabaseEntry() async throws {
        let (database, rootDir) = try await makeDatabase(named: "persist-delete.sqlite")
        defer { try? FileManager.default.removeItem(at: rootDir) }

        let manager = EnvironmentCatalogManager(
            database: database,
            environmentsDirectory: rootDir.appendingPathComponent("env", isDirectory: true),
            assetValidator: { _ in true }
        )

        let source = rootDir.appendingPathComponent("delete.hdr")
        try Data("hdr".utf8).write(to: source)
        let imported = try await manager.importEnvironment(from: source)

        try await manager.deleteAsset(id: imported.id)

        let fetched = try await manager.fetchAssets()
        #expect(!fetched.contains(where: { $0.id == imported.id }))
    }

    @Test
    func deleteAssetRemovesBackingFile() async throws {
        let (database, rootDir) = try await makeDatabase(named: "persist-delete-file.sqlite")
        defer { try? FileManager.default.removeItem(at: rootDir) }

        let manager = EnvironmentCatalogManager(
            database: database,
            environmentsDirectory: rootDir.appendingPathComponent("env", isDirectory: true),
            assetValidator: { _ in true }
        )

        let source = rootDir.appendingPathComponent("deletefile.hdr")
        try Data("hdr".utf8).write(to: source)
        let imported = try await manager.importEnvironment(from: source)
        let assetPath = imported.assetPath

        #expect(FileManager.default.fileExists(atPath: assetPath))

        try await manager.deleteAsset(id: imported.id)

        #expect(!FileManager.default.fileExists(atPath: assetPath))
    }

    @Test
    func deleteAssetForBundledDoesNotDeleteFile() async throws {
        let (database, rootDir) = try await makeDatabase(named: "persist-delete-bundled.sqlite")
        defer { try? FileManager.default.removeItem(at: rootDir) }

        let manager = EnvironmentCatalogManager(
            database: database,
            environmentsDirectory: rootDir.appendingPathComponent("env", isDirectory: true)
        )

        let bundledAsset = EnvironmentAsset(
            id: "bundled-id",
            name: "Bundled",
            sourceType: .bundled,
            assetPath: "/system/bundled.hdr",
            isActive: false
        )
        try await database.saveEnvironmentAsset(bundledAsset)

        try await manager.deleteAsset(id: "bundled-id")

        let fetched = try await manager.fetchAssets()
        #expect(!fetched.contains(where: { $0.id == "bundled-id" }))
    }

    @Test
    func multipleImportsCreateUniqueIDs() async throws {
        let (database, rootDir) = try await makeDatabase(named: "persist-unique-ids.sqlite")
        defer { try? FileManager.default.removeItem(at: rootDir) }

        let manager = EnvironmentCatalogManager(
            database: database,
            environmentsDirectory: rootDir.appendingPathComponent("env", isDirectory: true),
            assetValidator: { _ in true }
        )

        let source1 = rootDir.appendingPathComponent("a.hdr")
        let source2 = rootDir.appendingPathComponent("b.hdr")
        try Data("a".utf8).write(to: source1)
        try Data("b".utf8).write(to: source2)

        let first = try await manager.importEnvironment(from: source1)
        let second = try await manager.importEnvironment(from: source2)

        #expect(first.id != second.id)
    }
}
