import Foundation
import CoreGraphics
import ImageIO
import Synchronization
import Testing
import UniformTypeIdentifiers
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

    private func writeSolidPNG(width: Int, height: Int, to url: URL) throws {
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            throw NSError(domain: "EnvironmentCatalogManagerValidationTests", code: 1)
        }

        context.setFillColor(CGColor(red: 0.2, green: 0.3, blue: 0.4, alpha: 1.0))
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        guard let image = context.makeImage(),
              let destination = CGImageDestinationCreateWithURL(
                  url as CFURL,
                  UTType.png.identifier as CFString,
                  1,
                  nil
              ) else {
            throw NSError(domain: "EnvironmentCatalogManagerValidationTests", code: 2)
        }

        CGImageDestinationAddImage(destination, image, nil)
        guard CGImageDestinationFinalize(destination) else {
            throw NSError(domain: "EnvironmentCatalogManagerValidationTests", code: 3)
        }
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
    func unsupportedFileTypeErrorListsAllAcceptedEnvironmentFormats() {
        let message = EnvironmentCatalogError.unsupportedFileType.errorDescription ?? ""

        for ext in EnvironmentImportValidationPolicy.supportedExtensions {
            #expect(message.contains(".\(ext)"))
        }
    }

    @Test
    func importAcceptsExtensionCaseInsensitiveAndStoresNormalizedExtension() async throws {
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
        #expect(imported.assetPath.hasSuffix(".hdr"))
    }

    @Test
    func importRejectsUnsupportedExtensions() async throws {
        let (database, rootDir) = try await makeDatabase(named: "validation-unsupported-multi.sqlite")
        defer { try? FileManager.default.removeItem(at: rootDir) }

        let manager = EnvironmentCatalogManager(
            database: database,
            environmentsDirectory: rootDir.appendingPathComponent("env", isDirectory: true)
        )

        let unsupportedExtensions = ["mp4", "mov", "pdf", "txt"]

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
    func importRejectsSymbolicLinkBeforeValidation() async throws {
        let (database, rootDir) = try await makeDatabase(named: "validation-symlink-source.sqlite")
        defer { try? FileManager.default.removeItem(at: rootDir) }

        let validationCalls = Mutex(0)
        let manager = EnvironmentCatalogManager(
            database: database,
            environmentsDirectory: rootDir.appendingPathComponent("env", isDirectory: true),
            assetValidator: { _ in
                validationCalls.withLock { $0 += 1 }
                return true
            }
        )
        let outside = rootDir.appendingPathComponent("outside.hdr")
        try Data("hdr".utf8).write(to: outside)
        let symlink = rootDir.appendingPathComponent("linked.hdr")
        try FileManager.default.createSymbolicLink(at: symlink, withDestinationURL: outside)

        do {
            _ = try await manager.importEnvironment(from: symlink)
            Issue.record("Expected symbolic link import rejection")
        } catch EnvironmentCatalogError.missingFile {
            #expect(Bool(true))
        } catch {
            Issue.record("Unexpected error: \(error)")
        }

        #expect(validationCalls.withLock { $0 } == 0)
        #expect(try await manager.fetchAssets().isEmpty)
    }

    @Test
    func importRejectsDirectoryBeforeValidation() async throws {
        let (database, rootDir) = try await makeDatabase(named: "validation-directory-source.sqlite")
        defer { try? FileManager.default.removeItem(at: rootDir) }

        let validationCalls = Mutex(0)
        let manager = EnvironmentCatalogManager(
            database: database,
            environmentsDirectory: rootDir.appendingPathComponent("env", isDirectory: true),
            assetValidator: { _ in
                validationCalls.withLock { $0 += 1 }
                return true
            }
        )
        let directory = rootDir.appendingPathComponent("folder.hdr", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        do {
            _ = try await manager.importEnvironment(from: directory)
            Issue.record("Expected directory import rejection")
        } catch EnvironmentCatalogError.missingFile {
            #expect(Bool(true))
        } catch {
            Issue.record("Unexpected error: \(error)")
        }

        #expect(validationCalls.withLock { $0 } == 0)
        #expect(try await manager.fetchAssets().isEmpty)
    }

    @Test
    func importRejectsNonFileURLEvenWhenPathExistsLocally() async throws {
        let (database, rootDir) = try await makeDatabase(named: "validation-non-file-url.sqlite")
        defer { try? FileManager.default.removeItem(at: rootDir) }

        let validationCalls = Mutex(0)
        let manager = EnvironmentCatalogManager(
            database: database,
            environmentsDirectory: rootDir.appendingPathComponent("env", isDirectory: true),
            assetValidator: { _ in
                validationCalls.withLock { $0 += 1 }
                return true
            }
        )
        let source = rootDir.appendingPathComponent("local.hdr")
        try Data("hdr".utf8).write(to: source)
        let nonFileURL = try #require(URL(string: "https://example.com\(source.path)"))

        do {
            _ = try await manager.importEnvironment(from: nonFileURL)
            Issue.record("Expected missing file error")
        } catch EnvironmentCatalogError.missingFile {
            #expect(Bool(true))
        } catch {
            Issue.record("Unexpected error: \(error)")
        }

        #expect(validationCalls.withLock { $0 } == 0)
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

        let supportedExtensions = EnvironmentImportValidationPolicy.supportedExtensions.sorted()

        for ext in supportedExtensions {
            let source = rootDir.appendingPathComponent("file.\(ext)")
            try Data("\(ext) data".utf8).write(to: source)

            let imported = try await manager.importEnvironment(from: source)
            #expect(imported.assetPath.hasSuffix(".\(ext)"))
        }
    }

    @Test
    func defaultValidatorAcceptsEquirectangularPNGEnvironment() async throws {
        let (database, rootDir) = try await makeDatabase(named: "validation-panorama-png.sqlite")
        defer { try? FileManager.default.removeItem(at: rootDir) }

        let manager = EnvironmentCatalogManager(
            database: database,
            environmentsDirectory: rootDir.appendingPathComponent("env", isDirectory: true)
        )
        let source = rootDir.appendingPathComponent("panorama.png")
        try writeSolidPNG(
            width: EnvironmentImportValidationPolicy.minimumPanoramaWidth,
            height: EnvironmentImportValidationPolicy.minimumPanoramaHeight,
            to: source
        )

        let imported = try await manager.importEnvironment(from: source)

        #expect(imported.assetPath.hasSuffix(".png"))
        #expect(imported.sourceType == .imported)
    }

    @Test
    func defaultValidatorRejectsEmptyRealityEnvironment() async throws {
        let (database, rootDir) = try await makeDatabase(named: "validation-empty-reality.sqlite")
        defer { try? FileManager.default.removeItem(at: rootDir) }

        let manager = EnvironmentCatalogManager(
            database: database,
            environmentsDirectory: rootDir.appendingPathComponent("env", isDirectory: true)
        )
        let source = rootDir.appendingPathComponent("empty.reality")
        try Data().write(to: source)

        do {
            _ = try await manager.importEnvironment(from: source)
            Issue.record("Expected invalid asset error")
        } catch EnvironmentCatalogError.invalidAsset {
            #expect(Bool(true))
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }

    @Test
    func defaultValidatorRejectsRegularPhotoPNGEnvironment() async throws {
        let (database, rootDir) = try await makeDatabase(named: "validation-square-png.sqlite")
        defer { try? FileManager.default.removeItem(at: rootDir) }

        let manager = EnvironmentCatalogManager(
            database: database,
            environmentsDirectory: rootDir.appendingPathComponent("env", isDirectory: true)
        )
        let source = rootDir.appendingPathComponent("square.png")
        try writeSolidPNG(width: 12, height: 12, to: source)

        do {
            _ = try await manager.importEnvironment(from: source)
            Issue.record("Expected invalid asset error")
        } catch EnvironmentCatalogError.invalidAsset {
            #expect(Bool(true))
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }

    @Test
    func defaultValidatorRejectsLowResolutionPanoramaPNGEnvironment() async throws {
        let (database, rootDir) = try await makeDatabase(named: "validation-low-resolution-png.sqlite")
        defer { try? FileManager.default.removeItem(at: rootDir) }

        let manager = EnvironmentCatalogManager(
            database: database,
            environmentsDirectory: rootDir.appendingPathComponent("env", isDirectory: true)
        )
        let source = rootDir.appendingPathComponent("tiny-panorama.png")
        try writeSolidPNG(width: 512, height: 256, to: source)

        do {
            _ = try await manager.importEnvironment(from: source)
            Issue.record("Expected invalid asset error")
        } catch EnvironmentCatalogError.invalidAsset {
            #expect(Bool(true))
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }

    @Test
    func defaultValidatorRejectsTruncatedPanoramaPNGEnvironment() async throws {
        let (database, rootDir) = try await makeDatabase(named: "validation-truncated-png.sqlite")
        defer { try? FileManager.default.removeItem(at: rootDir) }

        let manager = EnvironmentCatalogManager(
            database: database,
            environmentsDirectory: rootDir.appendingPathComponent("env", isDirectory: true)
        )
        let source = rootDir.appendingPathComponent("truncated.png")
        let complete = rootDir.appendingPathComponent("complete.png")
        try writeSolidPNG(width: 20, height: 10, to: complete)
        let completeData = try Data(contentsOf: complete)
        try completeData.prefix(max(1, completeData.count / 2)).write(to: source)

        do {
            _ = try await manager.importEnvironment(from: source)
            Issue.record("Expected invalid asset error")
        } catch EnvironmentCatalogError.invalidAsset {
            #expect(Bool(true))
        } catch {
            Issue.record("Unexpected error: \(error)")
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

    @Test
    func importCuratedPresetReimportsWhenExistingPresetBackingFileIsMissing() async throws {
        let (database, rootDir) = try await makeDatabase(named: "validation-curated-missing-file.sqlite")
        defer { try? FileManager.default.removeItem(at: rootDir) }

        let environmentsDirectory = rootDir.appendingPathComponent("env", isDirectory: true)
        let manager = EnvironmentCatalogManager(
            database: database,
            environmentsDirectory: environmentsDirectory,
            assetValidator: { _ in true },
            remoteDataFetcher: { url in
                let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
                return (Data("HDR".utf8), response)
            }
        )

        let preset = CuratedEnvironmentPreset(
            id: "missing-curated-preset",
            name: "Missing Curated Theater",
            description: "A curated preset whose installed file was deleted",
            provider: .polyHaven,
            downloadURL: URL(string: "https://example.com/missing-curated.hdr")!,
            sourceAttributionURL: "https://example.com/missing-curated",
            licenseName: "CC0"
        )
        let staleAsset = EnvironmentAsset(
            id: "stale-curated-preset",
            name: preset.name,
            sourceType: .imported,
            assetPath: environmentsDirectory.appendingPathComponent("deleted-preset.hdr").path,
            licenseName: preset.licenseName,
            sourceAttributionURL: preset.sourceAttributionURL
        )
        try await database.saveEnvironmentAsset(staleAsset)

        let imported = try await manager.importCuratedPreset(preset)
        let assets = try await manager.fetchAssets()

        #expect(imported.id != staleAsset.id)
        #expect(imported.name == preset.name)
        #expect(FileManager.default.fileExists(atPath: imported.assetPath))
        #expect(!assets.contains(where: { $0.id == staleAsset.id }))
        #expect(assets.contains(where: { $0.id == imported.id }))
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
    func activateAssetWithInvalidIDDoesNotClearActiveAssetOrPersistPreference() async throws {
        let (database, rootDir) = try await makeDatabase(named: "fetch-activate-invalid.sqlite")
        defer { try? FileManager.default.removeItem(at: rootDir) }

        let manager = EnvironmentCatalogManager(
            database: database,
            environmentsDirectory: rootDir.appendingPathComponent("env", isDirectory: true),
            assetValidator: { _ in true }
        )

        let source = rootDir.appendingPathComponent("active.hdr")
        try Data("hdr".utf8).write(to: source)
        let imported = try await manager.importEnvironment(from: source)
        try await manager.activateAsset(id: imported.id)
        try await database.setSetting(key: SettingsKeys.activeEnvironmentSelectionCleared, value: nil)

        try await manager.activateAsset(id: "nonexistent-id")

        let active = try await manager.activeAsset()
        let preferred = try await database.getSetting(key: SettingsKeys.preferredEnvironment)
        let cleared = try await database.getSetting(key: SettingsKeys.activeEnvironmentSelectionCleared)

        #expect(active?.id == imported.id)
        #expect(preferred == imported.id)
        #expect(cleared == nil)
    }

    @Test
    func activateAssetWithUnresolvableBundledAssetDoesNotReplaceCurrentSelection() async throws {
        let (database, rootDir) = try await makeDatabase(named: "fetch-activate-unresolvable-bundle.sqlite")
        defer { try? FileManager.default.removeItem(at: rootDir) }

        let manager = EnvironmentCatalogManager(
            database: database,
            environmentsDirectory: rootDir.appendingPathComponent("env", isDirectory: true),
            assetValidator: { _ in true }
        )

        let source = rootDir.appendingPathComponent("active.hdr")
        try Data("hdr".utf8).write(to: source)
        let imported = try await manager.importEnvironment(from: source)
        try await manager.activateAsset(id: imported.id)
        try await database.setSetting(key: SettingsKeys.activeEnvironmentSelectionCleared, value: nil)

        let staleBundled = EnvironmentAsset(
            id: "missing-bundled-environment",
            name: "Missing Bundled Environment",
            sourceType: .bundled,
            assetPath: "bundle://missing-environment.usdz"
        )
        try await database.saveEnvironmentAsset(staleBundled)

        let activated = try await manager.activateAsset(id: staleBundled.id)
        let active = try await manager.activeAsset()
        let preferred = try await database.getSetting(key: SettingsKeys.preferredEnvironment)
        let cleared = try await database.getSetting(key: SettingsKeys.activeEnvironmentSelectionCleared)

        #expect(!activated)
        #expect(active?.id == imported.id)
        #expect(preferred == imported.id)
        #expect(cleared == nil)
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
    func deleteLastActiveAssetClearsActiveSelection() async throws {
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
        #expect(activeAfter == nil)
        #expect(try await manager.fetchAssets().contains { $0.id == first.id })
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
