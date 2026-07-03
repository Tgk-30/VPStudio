import Testing
import Foundation
@testable import VPStudio

@Suite("CuratedEnvironmentProvider Properties")
struct CuratedEnvironmentProviderModelUnitTests {
    @Test("Display names are correct")
    func displayNames() {
        #expect(CuratedEnvironmentProvider.official.displayName == "Official")
        #expect(CuratedEnvironmentProvider.github.displayName == "GitHub")
        #expect(CuratedEnvironmentProvider.polyHaven.displayName == "Poly Haven")
    }

    @Test("All cases are available")
    func allCases() {
        let allProviders = CuratedEnvironmentProvider.allCases
        #expect(allProviders.contains(.official))
        #expect(allProviders.contains(.github))
        #expect(allProviders.contains(.polyHaven))
        #expect(allProviders.count == 3)
    }
}

@Suite("CuratedEnvironmentPreset Properties")
struct CuratedEnvironmentPresetModelUnitTests {
    @Test("Preset properties are set correctly")
    func presetProperties() {
        let preset = CuratedEnvironmentPreset(
            id: "preset-123",
            name: "Test Preset",
            description: "A test environment",
            provider: .official,
            downloadURL: URL(string: "https://example.com/preset.zip")!,
            sourceAttributionURL: "https://example.com",
            licenseName: "MIT",
            defaultHdriYawOffset: 45.0
        )

        #expect(preset.id == "preset-123")
        #expect(preset.name == "Test Preset")
        #expect(preset.description == "A test environment")
        #expect(preset.provider == .official)
        #expect(preset.downloadURL == URL(string: "https://example.com/preset.zip")!)
        #expect(preset.sourceAttributionURL == "https://example.com")
        #expect(preset.licenseName == "MIT")
        #expect(preset.defaultHdriYawOffset == 45.0)
    }

    @Test("Preset with nil yaw offset")
    func nilYawOffset() {
        let preset = CuratedEnvironmentPreset(
            id: "preset-123",
            name: "Test Preset",
            description: "A test environment",
            provider: .github,
            downloadURL: URL(string: "https://example.com/preset.zip")!,
            sourceAttributionURL: "https://example.com",
            licenseName: "MIT",
            defaultHdriYawOffset: nil
        )

        #expect(preset.defaultHdriYawOffset == nil)
    }

    @Test("defaultEnvironmentTag defaults to nil")
    func environmentTagDefaultsToNil() {
        let preset = CuratedEnvironmentPreset(
            id: "preset-123",
            name: "Test Preset",
            description: "A test environment",
            provider: .github,
            downloadURL: URL(string: "https://example.com/preset.zip")!,
            sourceAttributionURL: "https://example.com",
            licenseName: "MIT"
        )

        #expect(preset.defaultEnvironmentTag == nil)
    }

    @Test("defaultEnvironmentTag is preserved on init")
    func environmentTagPreserved() {
        let preset = CuratedEnvironmentPreset(
            id: "preset-123",
            name: "Test Preset",
            description: "A test environment",
            provider: .polyHaven,
            downloadURL: URL(string: "https://example.com/preset.hdr")!,
            sourceAttributionURL: "https://example.com",
            licenseName: "CC0",
            defaultEnvironmentTag: "cinema"
        )

        #expect(preset.defaultEnvironmentTag == "cinema")
    }
}

@Suite("CuratedEnvironmentPreset Equatable")
struct CuratedEnvironmentPresetEquatableModelUnitTests {
    @Test("Presets with same properties are equal")
    func equalPresets() {
        let preset1 = CuratedEnvironmentPreset(
            id: "preset-123",
            name: "Test Preset",
            description: "A test environment",
            provider: .official,
            downloadURL: URL(string: "https://example.com/preset.zip")!,
            sourceAttributionURL: "https://example.com",
            licenseName: "MIT",
            defaultHdriYawOffset: 45.0
        )

        let preset2 = CuratedEnvironmentPreset(
            id: "preset-123",
            name: "Test Preset",
            description: "A test environment",
            provider: .official,
            downloadURL: URL(string: "https://example.com/preset.zip")!,
            sourceAttributionURL: "https://example.com",
            licenseName: "MIT",
            defaultHdriYawOffset: 45.0
        )

        #expect(preset1 == preset2)
    }

    @Test("Presets with different IDs are not equal")
    func differentIDs() {
        let preset1 = CuratedEnvironmentPreset(
            id: "preset-123",
            name: "Test Preset",
            description: "A test environment",
            provider: .official,
            downloadURL: URL(string: "https://example.com/preset.zip")!,
            sourceAttributionURL: "https://example.com",
            licenseName: "MIT"
        )

        let preset2 = CuratedEnvironmentPreset(
            id: "preset-456",
            name: "Test Preset",
            description: "A test environment",
            provider: .official,
            downloadURL: URL(string: "https://example.com/preset.zip")!,
            sourceAttributionURL: "https://example.com",
            licenseName: "MIT"
        )

        #expect(preset1 != preset2)
    }

    @Test("Presets with different providers are not equal")
    func differentProviders() {
        let preset1 = CuratedEnvironmentPreset(
            id: "preset-123",
            name: "Test Preset",
            description: "A test environment",
            provider: .official,
            downloadURL: URL(string: "https://example.com/preset.zip")!,
            sourceAttributionURL: "https://example.com",
            licenseName: "MIT"
        )

        let preset2 = CuratedEnvironmentPreset(
            id: "preset-123",
            name: "Test Preset",
            description: "A test environment",
            provider: .github,
            downloadURL: URL(string: "https://example.com/preset.zip")!,
            sourceAttributionURL: "https://example.com",
            licenseName: "MIT"
        )

        #expect(preset1 != preset2)
    }
}

@Suite("CuratedEnvironmentPreset Asset Mapping")
struct CuratedEnvironmentPresetAssetMappingModelUnitTests {
    @Test("Preset can be mapped to environment asset")
    func assetMapping() {
        let preset = CuratedEnvironmentPreset(
            id: "preset-123",
            name: "Test Preset",
            description: "A test environment",
            provider: .polyHaven,
            downloadURL: URL(string: "https://example.com/preset.zip")!,
            sourceAttributionURL: "https://example.com",
            licenseName: "CC0",
            defaultHdriYawOffset: 90.0
        )

        let asset = EnvironmentAsset(
            id: "asset-456",
            name: preset.name,
            sourceType: .imported,
            assetPath: "/path/to/asset.usdz",
            licenseName: preset.licenseName,
            sourceAttributionURL: preset.sourceAttributionURL,
            hdriYawOffset: preset.defaultHdriYawOffset
        )

        #expect(asset.name == preset.name)
        #expect(asset.licenseName == preset.licenseName)
        #expect(asset.sourceAttributionURL == preset.sourceAttributionURL)
        #expect(asset.hdriYawOffset == preset.defaultHdriYawOffset)
    }
}
