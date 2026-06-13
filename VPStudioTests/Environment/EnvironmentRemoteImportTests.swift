import Foundation
import Testing
@testable import VPStudio

@Suite("EnvironmentCatalogManager Remote Import Tests", .serialized)
struct EnvironmentRemoteImportTests {

    private func makeDatabase(named fileName: String) async throws -> (DatabaseManager, URL) {
        let rootDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: rootDir, withIntermediateDirectories: true)
        let database = try DatabaseManager(inMemoryNamed: "\(fileName)-\(UUID().uuidString)")
        try await database.migrate()
        return (database, rootDir)
    }

    @Test
    func importEnvironmentFromRemoteSuccess() async throws {
        let (database, rootDir) = try await makeDatabase(named: "remote-import-success.sqlite")
        defer { try? FileManager.default.removeItem(at: rootDir) }

        let manager = EnvironmentCatalogManager(
            database: database,
            environmentsDirectory: rootDir.appendingPathComponent("env", isDirectory: true),
            assetValidator: { _ in true },
            remoteDataFetcher: { url in
                let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
                return (Data("HDR DATA".utf8), response)
            }
        )

        let result = try await manager.importEnvironment(
            fromRemote: URL(string: "https://example.com/cinema.hdr")!
        )

        #expect(result.name == "cinema")
        #expect(result.sourceType == .imported)
        #expect(result.assetPath.hasSuffix(".hdr"))
    }

    @Test
    func importEnvironmentFromRemoteWithPreferredName() async throws {
        let (database, rootDir) = try await makeDatabase(named: "remote-import-name.sqlite")
        defer { try? FileManager.default.removeItem(at: rootDir) }

        let manager = EnvironmentCatalogManager(
            database: database,
            environmentsDirectory: rootDir.appendingPathComponent("env", isDirectory: true),
            assetValidator: { _ in true },
            remoteDataFetcher: { url in
                let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
                return (Data("HDR".utf8), response)
            }
        )

        let result = try await manager.importEnvironment(
            fromRemote: URL(string: "https://example.com/some-path.hdr")!,
            preferredName: "My Custom Cinema"
        )

        #expect(result.name == "My Custom Cinema")
    }

    @Test
    func importEnvironmentFromRemoteWithLicenseAndAttribution() async throws {
        let (database, rootDir) = try await makeDatabase(named: "remote-import-metadata.sqlite")
        defer { try? FileManager.default.removeItem(at: rootDir) }

        let manager = EnvironmentCatalogManager(
            database: database,
            environmentsDirectory: rootDir.appendingPathComponent("env", isDirectory: true),
            assetValidator: { _ in true },
            remoteDataFetcher: { url in
                let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
                return (Data("HDR".utf8), response)
            }
        )

        let result = try await manager.importEnvironment(
            fromRemote: URL(string: "https://example.com/env.hdr")!,
            licenseName: "CC0 1.0 Universal",
            sourceAttributionURL: "https://polyhaven.com/a/sky"
        )

        #expect(result.licenseName == "CC0 1.0 Universal")
        #expect(result.sourceAttributionURL == "https://polyhaven.com/a/sky")
    }

    @Test
    func importEnvironmentFromRemoteHTTPError() async throws {
        let (database, rootDir) = try await makeDatabase(named: "remote-http-error.sqlite")
        defer { try? FileManager.default.removeItem(at: rootDir) }

        let manager = EnvironmentCatalogManager(
            database: database,
            environmentsDirectory: rootDir.appendingPathComponent("env", isDirectory: true),
            remoteDataFetcher: { url in
                let response = HTTPURLResponse(url: url, statusCode: 404, httpVersion: nil, headerFields: nil)!
                return (Data(), response)
            }
        )

        do {
            _ = try await manager.importEnvironment(
                fromRemote: URL(string: "https://example.com/notfound.hdr")!
            )
            Issue.record("Expected download failed error")
        } catch EnvironmentCatalogError.downloadFailed(let reason) {
            #expect(reason.contains("404") || reason.contains("HTTP 404"))
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }

    @Test
    func importEnvironmentFromRemoteNetworkError() async throws {
        let (database, rootDir) = try await makeDatabase(named: "remote-network-error.sqlite")
        defer { try? FileManager.default.removeItem(at: rootDir) }

        struct NetworkError: Error {}
        let manager = EnvironmentCatalogManager(
            database: database,
            environmentsDirectory: rootDir.appendingPathComponent("env", isDirectory: true),
            remoteDataFetcher: { _ in throw NetworkError() }
        )

        do {
            _ = try await manager.importEnvironment(
                fromRemote: URL(string: "https://example.com/error.hdr")!
            )
            Issue.record("Expected download failed error")
        } catch EnvironmentCatalogError.downloadFailed {
            #expect(Bool(true))
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }

    @Test
    func importEnvironmentFromRemoteEmptyData() async throws {
        let (database, rootDir) = try await makeDatabase(named: "remote-empty-data.sqlite")
        defer { try? FileManager.default.removeItem(at: rootDir) }

        let manager = EnvironmentCatalogManager(
            database: database,
            environmentsDirectory: rootDir.appendingPathComponent("env", isDirectory: true),
            remoteDataFetcher: { url in
                let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
                return (Data(), response)
            }
        )

        do {
            _ = try await manager.importEnvironment(
                fromRemote: URL(string: "https://example.com/empty.hdr")!
            )
            Issue.record("Expected download failed error")
        } catch EnvironmentCatalogError.downloadFailed(let reason) {
            #expect(reason.contains("No data") || reason.contains("empty"))
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }

    @Test
    func importEnvironmentFromRemoteWithURLProtocolHarness() async throws {
        let (database, rootDir) = try await makeDatabase(named: "remote-harness.sqlite")
        defer { try? FileManager.default.removeItem(at: rootDir) }

        let session = URLProtocolHarness.makeSession { request in
            #expect(request.url?.absoluteString.contains("example.com") == true)
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, Data("HDR content".utf8))
        }

        let manager = EnvironmentCatalogManager(
            database: database,
            environmentsDirectory: rootDir.appendingPathComponent("env", isDirectory: true),
            assetValidator: { _ in true },
            remoteDataFetcher: { url in
                try await session.data(for: URLRequest(url: url))
            }
        )

        let result = try await manager.importEnvironment(
            fromRemote: URL(string: "https://example.com/harness-test.hdr")!
        )

        #expect(result.assetPath.hasSuffix(".hdr"))
        #expect(FileManager.default.fileExists(atPath: result.assetPath))
    }

    @Test
    func importEnvironmentFromRemoteHTTP500() async throws {
        let (database, rootDir) = try await makeDatabase(named: "remote-500.sqlite")
        defer { try? FileManager.default.removeItem(at: rootDir) }

        let manager = EnvironmentCatalogManager(
            database: database,
            environmentsDirectory: rootDir.appendingPathComponent("env", isDirectory: true),
            remoteDataFetcher: { url in
                let response = HTTPURLResponse(url: url, statusCode: 500, httpVersion: nil, headerFields: nil)!
                return (Data("Internal Server Error".utf8), response)
            }
        )

        do {
            _ = try await manager.importEnvironment(
                fromRemote: URL(string: "https://example.com/500.hdr")!
            )
            Issue.record("Expected download failed error")
        } catch EnvironmentCatalogError.downloadFailed(let reason) {
            #expect(reason.contains("500"))
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }

    @Test
    func importEnvironmentFromRemoteWithHDRIYawOffsetOverride() async throws {
        let (database, rootDir) = try await makeDatabase(named: "remote-yaw-override.sqlite")
        defer { try? FileManager.default.removeItem(at: rootDir) }

        let manager = EnvironmentCatalogManager(
            database: database,
            environmentsDirectory: rootDir.appendingPathComponent("env", isDirectory: true),
            assetValidator: { _ in true },
            remoteDataFetcher: { url in
                let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
                return (Data("HDR".utf8), response)
            }
        )

        let result = try await manager.importEnvironment(
            fromRemote: URL(string: "https://example.com/yaw-test.hdr")!,
            hdriYawOffset: 180.0
        )

        #expect(result.hdriYawOffset == 180.0)
    }

    @Test
    func importCuratedPresetAlreadyExistsReturnsExisting() async throws {
        let (database, rootDir) = try await makeDatabase(named: "curated-exists.sqlite")
        defer { try? FileManager.default.removeItem(at: rootDir) }

        let session = URLProtocolHarness.makeSession { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, Data("HDR".utf8))
        }

        let manager = EnvironmentCatalogManager(
            database: database,
            environmentsDirectory: rootDir.appendingPathComponent("env", isDirectory: true),
            assetValidator: { _ in true },
            remoteDataFetcher: { url in
                try await session.data(for: URLRequest(url: url))
            }
        )

        let preset = CuratedEnvironmentPreset(
            id: "existing-preset",
            name: "Test Theater",
            description: "A test theater",
            provider: .polyHaven,
            downloadURL: URL(string: "https://example.com/theater.hdr")!,
            sourceAttributionURL: "https://example.com",
            licenseName: "CC0"
        )

        let first = try await manager.importCuratedPreset(preset)
        let second = try await manager.importCuratedPreset(preset)

        #expect(first.id == second.id)
    }

    @Test
    func importCuratedPresetCreatesNewIfNotExists() async throws {
        let (database, rootDir) = try await makeDatabase(named: "curated-new.sqlite")
        defer { try? FileManager.default.removeItem(at: rootDir) }

        let manager = EnvironmentCatalogManager(
            database: database,
            environmentsDirectory: rootDir.appendingPathComponent("env", isDirectory: true),
            assetValidator: { _ in true },
            remoteDataFetcher: { url in
                let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
                return (Data("HDR".utf8), response)
            }
        )

        let preset = CuratedEnvironmentPreset(
            id: "new-preset",
            name: "New Theater",
            description: "A new theater",
            provider: .polyHaven,
            downloadURL: URL(string: "https://example.com/new.hdr")!,
            sourceAttributionURL: "https://example.com",
            licenseName: "CC0",
            defaultHdriYawOffset: 45.0
        )

        let imported = try await manager.importCuratedPreset(preset)

        #expect(imported.name == "New Theater")
        #expect(imported.hdriYawOffset == 45.0)
    }
}
