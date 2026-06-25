import Foundation
import Testing
@testable import VPStudio

@Suite("EnvironmentImportValidationPolicy supported extensions")
struct EnvironmentImportValidationPolicySupportTests {

    @Test func existingFormatsAreSupported() {
        #expect(EnvironmentImportValidationPolicy.isSupportedExtension("hdr"))
        #expect(EnvironmentImportValidationPolicy.isSupportedExtension("exr"))
        #expect(EnvironmentImportValidationPolicy.isSupportedExtension("usdz"))
        #expect(EnvironmentImportValidationPolicy.isSupportedExtension("reality"))
    }

    @Test func broadenedSkyboxFormatsAreSupported() {
        #expect(EnvironmentImportValidationPolicy.isSupportedExtension("png"))
        #expect(EnvironmentImportValidationPolicy.isSupportedExtension("jpg"))
        #expect(EnvironmentImportValidationPolicy.isSupportedExtension("jpeg"))
    }

    @Test func supportedExtensionOrderMatchesAcceptedExtensionSet() {
        #expect(Set(EnvironmentImportValidationPolicy.supportedExtensionOrder) == EnvironmentImportValidationPolicy.supportedExtensions)
        #expect(EnvironmentImportValidationPolicy.supportedExtensionOrder == ["hdr", "exr", "png", "jpg", "jpeg", "usdz", "reality"])
    }

    @Test func supportCheckIsCaseInsensitiveAndDotTolerant() {
        #expect(EnvironmentImportValidationPolicy.isSupportedExtension("HDR"))
        #expect(EnvironmentImportValidationPolicy.isSupportedExtension("UsDz"))
        #expect(EnvironmentImportValidationPolicy.isSupportedExtension(".PNG"))
        #expect(EnvironmentImportValidationPolicy.isSupportedExtension("  jpg "))
    }

    @Test func unsupportedExtensionsAreRejected() {
        #expect(!EnvironmentImportValidationPolicy.isSupportedExtension("txt"))
        #expect(!EnvironmentImportValidationPolicy.isSupportedExtension("mp4"))
        #expect(!EnvironmentImportValidationPolicy.isSupportedExtension(""))
        #expect(!EnvironmentImportValidationPolicy.isSupportedExtension("usd"))
    }

    @Test func normalizedExtensionStripsDotsCaseAndWhitespace() {
        #expect(EnvironmentImportValidationPolicy.normalizedExtension(for: ".HDR") == "hdr")
        #expect(EnvironmentImportValidationPolicy.normalizedExtension(for: "  Exr  ") == "exr")
        #expect(EnvironmentImportValidationPolicy.normalizedExtension(for: "PNG") == "png")
    }
}

@Suite("EnvironmentImportValidationPolicy classification")
struct EnvironmentImportValidationPolicyClassificationTests {

    @Test func hdrAndExrClassifyAsHDRHdri() {
        #expect(EnvironmentImportValidationPolicy.classify(extension: "hdr") == .hdri(isHDR: true))
        #expect(EnvironmentImportValidationPolicy.classify(extension: "EXR") == .hdri(isHDR: true))
    }

    @Test func pngAndJpgClassifyAsLDRHdri() {
        #expect(EnvironmentImportValidationPolicy.classify(extension: "png") == .hdri(isHDR: false))
        #expect(EnvironmentImportValidationPolicy.classify(extension: "jpg") == .hdri(isHDR: false))
        #expect(EnvironmentImportValidationPolicy.classify(extension: "jpeg") == .hdri(isHDR: false))
    }

    @Test func usdzAndRealityClassifyAsModel() {
        #expect(EnvironmentImportValidationPolicy.classify(extension: "usdz") == .model)
        #expect(EnvironmentImportValidationPolicy.classify(extension: "reality") == .model)
    }

    @Test func unknownExtensionClassifiesAsUnsupported() {
        #expect(EnvironmentImportValidationPolicy.classify(extension: "txt") == .unsupported)
        #expect(EnvironmentImportValidationPolicy.classify(extension: "") == .unsupported)
    }

    @Test func panoramaFormatsRouteToHDRISkybox() {
        #expect(EnvironmentImportValidationPolicy.routesToHDRISkybox(extension: "hdr"))
        #expect(EnvironmentImportValidationPolicy.routesToHDRISkybox(extension: "exr"))
        #expect(EnvironmentImportValidationPolicy.routesToHDRISkybox(extension: "png"))
        #expect(EnvironmentImportValidationPolicy.routesToHDRISkybox(extension: "jpg"))
        #expect(!EnvironmentImportValidationPolicy.routesToHDRISkybox(extension: "usdz"))
        #expect(!EnvironmentImportValidationPolicy.routesToHDRISkybox(extension: "reality"))
    }
}

@Suite("EnvironmentImportValidationPolicy size guard")
struct EnvironmentImportValidationPolicySizeTests {

    @Test func sizeWithinLimitIsAccepted() {
        #expect(EnvironmentImportValidationPolicy.isWithinSizeLimit(1))
        #expect(EnvironmentImportValidationPolicy.isWithinSizeLimit(EnvironmentImportValidationPolicy.maxFileSizeBytes))
        #expect(EnvironmentImportValidationPolicy.isWithinSizeLimit(EnvironmentImportValidationPolicy.maxFileSizeBytes - 1))
    }

    @Test func oversizeIsRejected() {
        #expect(!EnvironmentImportValidationPolicy.isWithinSizeLimit(EnvironmentImportValidationPolicy.maxFileSizeBytes + 1))
    }

    @Test func unknownOrZeroSizeIsAcceptedAndValidatedDownstream() {
        #expect(EnvironmentImportValidationPolicy.isWithinSizeLimit(0))
        #expect(EnvironmentImportValidationPolicy.isWithinSizeLimit(-1))
    }

    @Test func maxFileSizeConstantIsPositive() {
        #expect(EnvironmentImportValidationPolicy.maxFileSizeBytes > 0)
    }
}

@Suite("EnvironmentImportValidationPolicy panorama geometry")
struct EnvironmentImportValidationPolicyPanoramaGeometryTests {

    @Test func panoramaAspectRatioAcceptsEquirectangularImages() {
        #expect(EnvironmentImportValidationPolicy.hasPanoramaAspectRatio(width: 4096, height: 2048))
        #expect(EnvironmentImportValidationPolicy.hasPanoramaAspectRatio(width: 3840, height: 1920))
    }

    @Test func panoramaAspectRatioRejectsRegularPhotosAndInvalidDimensions() {
        #expect(!EnvironmentImportValidationPolicy.hasPanoramaAspectRatio(width: 2048, height: 2048))
        #expect(!EnvironmentImportValidationPolicy.hasPanoramaAspectRatio(width: 1080, height: 1920))
        #expect(!EnvironmentImportValidationPolicy.hasPanoramaAspectRatio(width: 0, height: 2048))
        #expect(!EnvironmentImportValidationPolicy.hasPanoramaAspectRatio(width: 4096, height: 0))
    }
}
