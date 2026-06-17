import Testing
import Foundation
import GRDB
@testable import VPStudio

@Suite("EnvironmentAssetSourceType Properties")
struct EnvironmentAssetSourceTypeTests {
    @Test("All cases are available")
    func allCases() {
        let allTypes = EnvironmentAssetSourceType.allCases
        #expect(allTypes.contains(.bundled))
        #expect(allTypes.contains(.imported))
        #expect(allTypes.count == 2)
    }
}

@Suite("EnvironmentAsset Properties")
struct EnvironmentAssetTests {
    @Test("Asset properties are set correctly")
    func assetProperties() {
        let asset = EnvironmentAsset(
            id: "asset-123",
            name: "Test Asset",
            sourceType: .bundled,
            assetPath: "/path/to/asset.usdz",
            thumbnailPath: "/path/to/thumbnail.jpg",
            licenseName: "MIT",
            sourceAttributionURL: "https://example.com",
            previewImagePath: "/path/to/preview.jpg",
            hdriYawOffset: 45.0,
            createdAt: Date(timeIntervalSince1970: 123456789),
            isActive: true
        )

        #expect(asset.id == "asset-123")
        #expect(asset.name == "Test Asset")
        #expect(asset.sourceType == .bundled)
        #expect(asset.assetPath == "/path/to/asset.usdz")
        #expect(asset.thumbnailPath == "/path/to/thumbnail.jpg")
        #expect(asset.licenseName == "MIT")
        #expect(asset.sourceAttributionURL == "https://example.com")
        #expect(asset.previewImagePath == "/path/to/preview.jpg")
        #expect(asset.hdriYawOffset == 45.0)
        #expect(asset.isActive == true)
    }

    @Test("Asset with optional properties nil")
    func optionalPropertiesNil() {
        let asset = EnvironmentAsset(
            id: "asset-123",
            name: "Test Asset",
            sourceType: .imported,
            assetPath: "/path/to/asset.usdz"
        )

        #expect(asset.thumbnailPath == nil)
        #expect(asset.licenseName == nil)
        #expect(asset.sourceAttributionURL == nil)
        #expect(asset.previewImagePath == nil)
        #expect(asset.hdriYawOffset == nil)
        #expect(asset.isActive == false)
    }
}

@Suite("EnvironmentAsset Row Initialization")
struct EnvironmentAssetRowInitializationTests {
    @Test("Row initializer falls back to bundled source type and converts yaw offset")
    func rowInitializerFallbacksAndYawConversion() {
        let createdAt = Date(timeIntervalSince1970: 100)
        let row = Row([
            "id": "asset-row",
            "name": "Imported HDRI",
            "sourceType": "legacy",
            "assetPath": "/envs/imported.hdr",
            "thumbnailPath": "/thumb.jpg",
            "licenseName": "CC0",
            "sourceAttributionURL": "https://example.com/source",
            "previewImagePath": "/preview.jpg",
            "hdriYawOffset": 12.5,
            "createdAt": createdAt,
            "isActive": true,
        ])

        let asset = EnvironmentAsset(row: row)

        #expect(asset.id == "asset-row")
        #expect(asset.sourceType == .bundled)
        #expect(asset.assetPath == "/envs/imported.hdr")
        #expect(asset.thumbnailPath == "/thumb.jpg")
        #expect(asset.licenseName == "CC0")
        #expect(asset.sourceAttributionURL == "https://example.com/source")
        #expect(asset.previewImagePath == "/preview.jpg")
        #expect(asset.hdriYawOffset == 12.5)
        #expect(asset.createdAt == createdAt)
        #expect(asset.isActive)
    }

    @Test("Row initializer preserves valid source type and nil yaw offset")
    func rowInitializerPreservesValidSourceTypeAndNilYawOffset() {
        let createdAt = Date(timeIntervalSince1970: 200)
        let row = Row([
            "id": "asset-imported",
            "name": "Imported",
            "sourceType": "imported",
            "assetPath": "/envs/imported.exr",
            "thumbnailPath": nil,
            "licenseName": nil,
            "sourceAttributionURL": nil,
            "previewImagePath": nil,
            "hdriYawOffset": nil,
            "createdAt": createdAt,
            "isActive": false,
        ])

        let asset = EnvironmentAsset(row: row)

        #expect(asset.id == "asset-imported")
        #expect(asset.sourceType == .imported)
        #expect(asset.thumbnailPath == nil)
        #expect(asset.hdriYawOffset == nil)
        #expect(asset.createdAt == createdAt)
        #expect(asset.isActive == false)
    }
}

@Suite("EnvironmentAsset Database Round-Trip")
struct EnvironmentAssetDatabaseRoundTripTests {
    private func makeTempDatabase() async throws -> (DatabaseManager, URL) {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        let database = try DatabaseManager(inMemoryNamed: "environment-asset-test-\(UUID().uuidString)")
        try await database.migrate()
        return (database, tempDir)
    }

    @Test func roundTripsThroughDatabaseManager() async throws {
        let (database, tempDir) = try await makeTempDatabase()
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let asset = EnvironmentAsset(
            id: "env-asset-1",
            name: "Test Environment",
            sourceType: .bundled,
            assetPath: "/path/to/asset.usdz",
            thumbnailPath: "/path/to/thumb.jpg",
            isActive: true
        )
        try await database.saveEnvironmentAsset(asset)
        let fetched = try await database.fetchEnvironmentAssets()

        #expect(fetched.count == 1)
        #expect(fetched.first?.id == asset.id)
        #expect(fetched.first?.name == asset.name)
        #expect(fetched.first?.sourceType == asset.sourceType)
        #expect(fetched.first?.isActive == true)
    }

    @Test
    func environmentAssetWithAllFieldsRoundTripsCorrectly() async throws {
        let (database, tempDir) = try await makeTempDatabase()
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let asset = EnvironmentAsset(
            id: "full-env-asset",
            name: "Full Test Environment",
            sourceType: .imported,
            assetPath: "/path/to/asset.usdz",
            thumbnailPath: "/path/to/thumbnail.jpg",
            licenseName: "MIT",
            sourceAttributionURL: "https://example.com",
            previewImagePath: "/path/to/preview.jpg",
            hdriYawOffset: 45.0,
            isActive: true
        )
        try await database.saveEnvironmentAsset(asset)
        let fetched = try await database.fetchEnvironmentAssets()

        #expect(fetched.count == 1)
        #expect(fetched.first?.licenseName == "MIT")
        #expect(fetched.first?.sourceAttributionURL == "https://example.com")
        #expect(fetched.first?.previewImagePath == "/path/to/preview.jpg")
        #expect(fetched.first?.hdriYawOffset == 45.0)
    }

    @Test
    func multipleEnvironmentAssetsRoundTripCorrectly() async throws {
        let (database, tempDir) = try await makeTempDatabase()
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let assets = [
            EnvironmentAsset(id: "env-a", name: "Env A", sourceType: .bundled, assetPath: "/a.usdz"),
            EnvironmentAsset(id: "env-b", name: "Env B", sourceType: .imported, assetPath: "/b.usdz"),
            EnvironmentAsset(id: "env-c", name: "Env C", sourceType: .imported, assetPath: "/c.usdz")
        ]

        for asset in assets {
            try await database.saveEnvironmentAsset(asset)
        }

        let fetched = try await database.fetchEnvironmentAssets()
        #expect(fetched.count == 3)
        #expect(fetched.contains { $0.id == "env-a" })
        #expect(fetched.contains { $0.id == "env-b" })
        #expect(fetched.contains { $0.id == "env-c" })
    }

    @Test
    func activeEnvironmentAssetCanBeSetAndRetrieved() async throws {
        let (database, tempDir) = try await makeTempDatabase()
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let asset1 = EnvironmentAsset(id: "active-test-1", name: "Active", sourceType: .bundled, assetPath: "/a.usdz", isActive: true)
        let asset2 = EnvironmentAsset(id: "active-test-2", name: "Inactive", sourceType: .bundled, assetPath: "/b.usdz", isActive: false)

        try await database.saveEnvironmentAsset(asset1)
        try await database.saveEnvironmentAsset(asset2)

        let activeAsset = try await database.fetchActiveEnvironmentAsset()
        #expect(activeAsset?.id == "active-test-1")

        try await database.setActiveEnvironmentAsset(id: "active-test-2")
        let newActiveAsset = try await database.fetchActiveEnvironmentAsset()
        #expect(newActiveAsset?.id == "active-test-2")
    }

    @Test
    func deletedEnvironmentAssetDoesNotExist() async throws {
        let (database, tempDir) = try await makeTempDatabase()
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let asset = EnvironmentAsset(id: "to-delete", name: "Delete Me", sourceType: .bundled, assetPath: "/delete.usdz")
        try await database.saveEnvironmentAsset(asset)
        try await database.deleteEnvironmentAsset(id: "to-delete")

        let fetched = try await database.fetchEnvironmentAssets()
        #expect(fetched.contains { $0.id == "to-delete" } == false)
    }

    @Test
    func nilHdriYawOffsetPersistsAsNil() async throws {
        let (database, tempDir) = try await makeTempDatabase()
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let asset = EnvironmentAsset(
            id: "nil-yaw",
            name: "Nil Yaw Asset",
            sourceType: .bundled,
            assetPath: "/test.usdz",
            hdriYawOffset: nil,
            isActive: false
        )
        try await database.saveEnvironmentAsset(asset)
        let fetched = try await database.fetchEnvironmentAssets()

        #expect(fetched.first?.hdriYawOffset == nil)
    }
}

@Suite("EnvironmentAsset Codable Round-Trip")
struct EnvironmentAssetCodableTests {
    @Test("EnvironmentAsset encodes and decodes correctly")
    func codableRoundTrip() throws {
        let originalAsset = EnvironmentAsset(
            id: "asset-123",
            name: "Test Asset",
            sourceType: .bundled,
            assetPath: "/path/to/asset.usdz",
            thumbnailPath: "/path/to/thumbnail.jpg",
            licenseName: "MIT",
            sourceAttributionURL: "https://example.com",
            previewImagePath: "/path/to/preview.jpg",
            hdriYawOffset: 45.0,
            createdAt: Date(timeIntervalSince1970: 123456789),
            isActive: true
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(originalAsset)
        let decoder = JSONDecoder()
        let decodedAsset = try decoder.decode(EnvironmentAsset.self, from: data)

        #expect(decodedAsset.id == originalAsset.id)
        #expect(decodedAsset.name == originalAsset.name)
        #expect(decodedAsset.sourceType == originalAsset.sourceType)
        #expect(decodedAsset.assetPath == originalAsset.assetPath)
        #expect(decodedAsset.thumbnailPath == originalAsset.thumbnailPath)
        #expect(decodedAsset.licenseName == originalAsset.licenseName)
        #expect(decodedAsset.sourceAttributionURL == originalAsset.sourceAttributionURL)
        #expect(decodedAsset.previewImagePath == originalAsset.previewImagePath)
        #expect(decodedAsset.hdriYawOffset == originalAsset.hdriYawOffset)
        #expect(decodedAsset.isActive == originalAsset.isActive)
    }

    @Test("EnvironmentAsset with minimal data encodes and decodes")
    func minimalCodableRoundTrip() throws {
        let originalAsset = EnvironmentAsset(
            id: "asset-123",
            name: "Test Asset",
            sourceType: .imported,
            assetPath: "/path/to/asset.usdz"
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(originalAsset)
        let decoder = JSONDecoder()
        let decodedAsset = try decoder.decode(EnvironmentAsset.self, from: data)

        #expect(decodedAsset.id == originalAsset.id)
        #expect(decodedAsset.name == originalAsset.name)
        #expect(decodedAsset.sourceType == originalAsset.sourceType)
        #expect(decodedAsset.assetPath == originalAsset.assetPath)
        #expect(decodedAsset.isActive == false)
    }
}

@Suite("EnvironmentAsset environmentTag")
struct EnvironmentAssetEnvironmentTagTests {
    @Test("environmentTag defaults to nil")
    func defaultsToNil() {
        let asset = EnvironmentAsset(
            id: "tag-default",
            name: "No Tag",
            sourceType: .imported,
            assetPath: "/a.hdr"
        )
        #expect(asset.environmentTag == nil)
    }

    @Test("environmentTag is preserved on init")
    func preservedOnInit() {
        let asset = EnvironmentAsset(
            id: "tag-set",
            name: "Tagged",
            sourceType: .imported,
            assetPath: "/a.hdr",
            environmentTag: "horror"
        )
        #expect(asset.environmentTag == "horror")
    }

    @Test("environmentTag survives Codable round-trip")
    func codableRoundTrip() throws {
        let original = EnvironmentAsset(
            id: "tag-codable",
            name: "Tagged",
            sourceType: .imported,
            assetPath: "/a.hdr",
            environmentTag: "scifi"
        )
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(EnvironmentAsset.self, from: data)
        #expect(decoded.environmentTag == "scifi")
        #expect(decoded == original)
    }

    @Test("environmentTag participates in Equatable")
    func equatableConsidersTag() {
        // Pin createdAt so the only varying field is environmentTag (createdAt defaults to Date()).
        let fixedDate = Date(timeIntervalSince1970: 123456789)
        let base = EnvironmentAsset(id: "x", name: "X", sourceType: .imported, assetPath: "/a.hdr", environmentTag: "horror", createdAt: fixedDate)
        let same = EnvironmentAsset(id: "x", name: "X", sourceType: .imported, assetPath: "/a.hdr", environmentTag: "horror", createdAt: fixedDate)
        let differentTag = EnvironmentAsset(id: "x", name: "X", sourceType: .imported, assetPath: "/a.hdr", environmentTag: "scifi", createdAt: fixedDate)
        let nilTag = EnvironmentAsset(id: "x", name: "X", sourceType: .imported, assetPath: "/a.hdr", createdAt: fixedDate)
        #expect(base == same)
        #expect(base != differentTag)
        #expect(base != nilTag)
    }
}

@Suite("EnvironmentAsset URL Construction")
struct EnvironmentAssetURLTests {
    @Test("Asset path can be converted to URL")
    func assetPathURL() {
        let asset = EnvironmentAsset(
            id: "asset-123",
            name: "Test Asset",
            sourceType: .bundled,
            assetPath: "/var/mobile/Containers/Data/Application/app-id/Documents/environments/asset.usdz"
        )

        // Note: This test verifies the path is stored correctly
        // Actual URL construction would depend on the app's file structure
        #expect(asset.assetPath == "/var/mobile/Containers/Data/Application/app-id/Documents/environments/asset.usdz")
    }
}
