#if os(visionOS)
import Foundation
import Testing
@testable import VPStudio

struct EnvironmentPreviewRowPolicyAdditionalTests {
    @Test
    func hdriDetectionIsCaseInsensitiveForHdrAndExr() {
        #expect(EnvironmentPreviewRowPolicy.isHDRIAsset(assetPath: "/tmp/sky.HDR"))
        #expect(EnvironmentPreviewRowPolicy.isHDRIAsset(assetPath: "/tmp/stage.exr"))
        #expect(EnvironmentPreviewRowPolicy.isHDRIAsset(assetPath: "/tmp/scene.usdz") == false)
    }

    @Test
    func iconNameTracksAssetKind() {
        #expect(EnvironmentPreviewRowPolicy.assetTypeIconName(forAssetPath: "/tmp/a.hdr") == "pano")
        #expect(EnvironmentPreviewRowPolicy.assetTypeIconName(forAssetPath: "/tmp/a.reality") == "cube.transparent")
    }

    @Test
    func labelPrefersBuiltInThenHdriThenScene() {
        #expect(
            EnvironmentPreviewRowPolicy.assetTypeLabel(
                sourceType: .bundled,
                assetPath: "/tmp/anything.usdz"
            ) == "Built-in"
        )
        #expect(
            EnvironmentPreviewRowPolicy.assetTypeLabel(
                sourceType: .imported,
                assetPath: "/tmp/a.exr"
            ) == "HDRI"
        )
        #expect(
            EnvironmentPreviewRowPolicy.assetTypeLabel(
                sourceType: .imported,
                assetPath: "/tmp/a.usdz"
            ) == "3D Scene"
        )
    }
}
#endif
