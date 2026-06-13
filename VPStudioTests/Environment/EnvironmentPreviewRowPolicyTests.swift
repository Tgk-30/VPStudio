#if os(visionOS)
import Testing
@testable import VPStudio

@Suite("Environment Preview Row Policy")
struct EnvironmentPreviewRowPolicyTests {
    @Test
    func detectsHdriAssetsByExtensionCaseInsensitively() {
        #expect(EnvironmentPreviewRowPolicy.isHDRIAsset(assetPath: "/assets/sky.hdr"))
        #expect(EnvironmentPreviewRowPolicy.isHDRIAsset(assetPath: "/assets/sky.EXR"))
        #expect(EnvironmentPreviewRowPolicy.isHDRIAsset(assetPath: "/assets/folder/scene.HdR"))
        #expect(EnvironmentPreviewRowPolicy.isHDRIAsset(assetPath: "/assets/scene.usdz") == false)
        #expect(EnvironmentPreviewRowPolicy.isHDRIAsset(assetPath: "/assets/scene") == false)
    }

    @Test
    func picksHdriAndSceneIconsFromAssetPath() {
        #expect(EnvironmentPreviewRowPolicy.assetTypeIconName(forAssetPath: "/assets/sky.hdr") == "pano")
        #expect(EnvironmentPreviewRowPolicy.assetTypeIconName(forAssetPath: "/assets/room.usdz") == "cube.transparent")
    }

    @Test
    func labelsBundledAssetsAsBuiltInRegardlessOfExtension() {
        #expect(
            EnvironmentPreviewRowPolicy.assetTypeLabel(
                sourceType: .bundled,
                assetPath: "/assets/anything.hdr"
            ) == "Built-in"
        )
        #expect(
            EnvironmentPreviewRowPolicy.assetTypeLabel(
                sourceType: .bundled,
                assetPath: "/assets/anything.usdz"
            ) == "Built-in"
        )
    }

    @Test
    func labelsImportedAssetsByClassification() {
        #expect(
            EnvironmentPreviewRowPolicy.assetTypeLabel(
                sourceType: .imported,
                assetPath: "/assets/anything.hdr"
            ) == "HDRI"
        )
        #expect(
            EnvironmentPreviewRowPolicy.assetTypeLabel(
                sourceType: .imported,
                assetPath: "/assets/anything.reality"
            ) == "3D Scene"
        )
    }
}
#endif
