import Foundation

/// Pure policy describing which files VPStudio accepts as importable immersive
/// environments, and how each extension routes (HDRI skybox vs. RealityKit model).
///
/// No I/O, no RealityKit — just classification + thresholds. `EnvironmentCatalogManager`
/// routes its `validateExtension` / `immersiveSpaceID` / `hdriExtensions` decisions
/// through here so the accepted-format list lives in one place.
enum EnvironmentImportValidationPolicy {

    /// How an accepted file is treated by the environment pipeline.
    enum Classification: Equatable, Sendable {
        /// 360° equirectangular skybox (HDR/EXR high-dynamic-range, or PNG/JPG LDR).
        /// Routes to the `hdriSkybox` immersive space.
        case hdri(isHDR: Bool)
        /// RealityKit model/scene (.usdz / .reality). Routes to `customEnvironment`.
        case model
        /// Not an importable environment file.
        case unsupported
    }

    /// High-dynamic-range panorama formats.
    static let hdrPanoramaExtensions: Set<String> = ["hdr", "exr"]

    /// Low-dynamic-range equirectangular image formats accepted as skyboxes.
    static let ldrPanoramaExtensions: Set<String> = ["png", "jpg", "jpeg"]

    /// RealityKit model/scene formats.
    static let modelExtensions: Set<String> = ["usdz", "reality"]

    /// Stable order for picker filters and reader-facing copy.
    static let supportedExtensionOrder = ["hdr", "exr", "png", "jpg", "jpeg", "usdz", "reality"]

    /// All extensions that route to the HDRI skybox space (HDR + LDR panoramas).
    static let hdriExtensions: Set<String> = hdrPanoramaExtensions.union(ldrPanoramaExtensions)

    /// Every accepted extension.
    static let supportedExtensions: Set<String> = Set(supportedExtensionOrder)

    /// Stable, reader-facing list for errors, prompts, and tests.
    static let supportedExtensionDisplayList = ".hdr, .exr, .png, .jpg, .jpeg, .usdz, or .reality"

    /// Hard cap on imported environment file size (bytes). 512 MB comfortably fits a
    /// 8K HDR panorama or a sizeable USDZ scene while rejecting accidental huge files.
    static let maxFileSizeBytes: Int = 512 * 1024 * 1024

    /// Equirectangular 360° panoramas should be approximately 2:1. Keep a little
    /// tolerance for encoder rounding/cropping, but reject regular photos that
    /// would visibly stretch across the immersive skybox.
    static let panoramaAspectRatioRange: ClosedRange<Double> = 1.75...2.25

    /// Lowercases and trims a raw extension (handles leading dots and whitespace).
    static func normalizedExtension(for raw: String) -> String {
        var ext = raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        while ext.hasPrefix(".") {
            ext.removeFirst()
        }
        return ext
    }

    /// Whether an extension (any case) is an importable environment format.
    static func isSupportedExtension(_ raw: String) -> Bool {
        supportedExtensions.contains(normalizedExtension(for: raw))
    }

    /// Classifies an extension into hdri / model / unsupported.
    static func classify(extension raw: String) -> Classification {
        let ext = normalizedExtension(for: raw)
        if hdrPanoramaExtensions.contains(ext) {
            return .hdri(isHDR: true)
        }
        if ldrPanoramaExtensions.contains(ext) {
            return .hdri(isHDR: false)
        }
        if modelExtensions.contains(ext) {
            return .model
        }
        return .unsupported
    }

    /// Whether an extension routes to the `hdriSkybox` immersive space.
    static func routesToHDRISkybox(extension raw: String) -> Bool {
        if case .hdri = classify(extension: raw) { return true }
        return false
    }

    /// Whether a file of the given byte size is within the import cap. Sizes <= 0 are
    /// treated as acceptable (size unknown / validated elsewhere).
    static func isWithinSizeLimit(_ byteCount: Int) -> Bool {
        guard byteCount > 0 else { return true }
        return byteCount <= maxFileSizeBytes
    }

    /// Whether decoded image dimensions look like a usable equirectangular panorama.
    static func hasPanoramaAspectRatio(width: Int, height: Int) -> Bool {
        guard width > 0, height > 0 else { return false }
        let ratio = Double(width) / Double(height)
        return panoramaAspectRatioRange.contains(ratio)
    }
}
