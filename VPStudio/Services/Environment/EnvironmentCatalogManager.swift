import Foundation
import ImageIO
import os
#if os(visionOS)
import RealityKit
#endif

enum EnvironmentCatalogError: LocalizedError {
    case unsupportedFileType
    case missingFile
    case invalidAsset
    case downloadFailed(String)

    var errorDescription: String? {
        switch self {
        case .unsupportedFileType:
            return "Unsupported environment file type. Use .usdz, .reality, .hdr, or .exr files."
        case .missingFile:
            return "Selected environment file could not be read."
        case .invalidAsset:
            return "Environment file could not be loaded by RealityKit."
        case .downloadFailed(let reason):
            return "Environment download failed: \(reason)"
        }
    }
}

actor EnvironmentCatalogManager {
    typealias RemoteDataFetcher = @Sendable (URL) async throws -> (Data, URLResponse)
    private static let logger = Logger(subsystem: "com.vpstudio", category: "environment-catalog")
    private static let defaultRemoteSession: URLSession = {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 30
        configuration.timeoutIntervalForResource = 300
        return URLSession(configuration: configuration)
    }()

    private let database: DatabaseManager
    private let fileManager: FileManager
    private let environmentsDirectory: URL
    private let assetValidator: @Sendable (URL) async -> Bool
    private let remoteDataFetcher: RemoteDataFetcher

    private static let supportedExtensions: Set<String> = EnvironmentImportValidationPolicy.supportedExtensions

    private static let hdriExtensions: Set<String> = EnvironmentImportValidationPolicy.hdriExtensions

    private static let curatedDefaults: [EnvironmentAsset] = []

    /// Validated URL from a hardcoded string.
    private static func presetURL(_ string: String) -> URL? {
        guard let url = URL(string: string) else {
            logger.error("Invalid hardcoded preset URL: \(string, privacy: .public)")
            return nil
        }
        return url
    }

    private static func preset(
        id: String,
        name: String,
        description: String,
        provider: CuratedEnvironmentProvider,
        downloadURLString: String,
        sourceAttributionURL: String,
        licenseName: String,
        defaultHdriYawOffset: Float? = nil
    ) -> CuratedEnvironmentPreset? {
        guard let downloadURL = presetURL(downloadURLString) else { return nil }
        return CuratedEnvironmentPreset(
            id: id,
            name: name,
            description: description,
            provider: provider,
            downloadURL: downloadURL,
            sourceAttributionURL: sourceAttributionURL,
            licenseName: licenseName,
            defaultHdriYawOffset: defaultHdriYawOffset
        )
    }

    private static let curatedRemotePresets: [CuratedEnvironmentPreset] = [
        preset(
            id: "polyhaven-pretville-cinema",
            name: "Pretville Cinema",
            description: "Vintage cinema interior with warm projection lighting. CC0 HDRI panorama.",
            provider: .polyHaven,
            downloadURLString: "https://dl.polyhaven.org/file/ph-assets/HDRIs/hdr/4k/pretville_cinema_4k.hdr",
            sourceAttributionURL: "https://polyhaven.com/a/pretville_cinema",
            licenseName: "CC0 1.0 Universal"
        ),
        preset(
            id: "polyhaven-cinema-hall",
            name: "Cinema Hall",
            description: "Grand cinema auditorium with atmospheric house lights. CC0 HDRI panorama.",
            provider: .polyHaven,
            downloadURLString: "https://dl.polyhaven.org/file/ph-assets/HDRIs/hdr/4k/cinema_hall_4k.hdr",
            sourceAttributionURL: "https://polyhaven.com/a/cinema_hall",
            licenseName: "CC0 1.0 Universal"
        ),
    ].compactMap { $0 }

    private static let builtInImmersiveSpaces: Set<String> = []

    nonisolated static var onlinePresets: [CuratedEnvironmentPreset] {
        curatedRemotePresets
    }

    private static func defaultRemoteDataFetcher(url: URL) async throws -> (Data, URLResponse) {
        try await defaultRemoteSession.data(from: url)
    }

    init(
        database: DatabaseManager,
        fileManager: FileManager = .default,
        environmentsDirectory: URL? = nil,
        assetValidator: (@Sendable (URL) async -> Bool)? = nil,
        remoteDataFetcher: RemoteDataFetcher? = nil
    ) {
        self.database = database
        self.fileManager = fileManager
        self.assetValidator = assetValidator ?? Self.defaultAssetValidator
        self.remoteDataFetcher = remoteDataFetcher ?? Self.defaultRemoteDataFetcher

        if let environmentsDirectory {
            self.environmentsDirectory = environmentsDirectory
        } else {
            let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
                ?? FileManager.default.temporaryDirectory
            self.environmentsDirectory = appSupport
                .appendingPathComponent("VPStudio", isDirectory: true)
                .appendingPathComponent("Environments", isDirectory: true)
        }
    }

    func bootstrapCuratedAssets() async throws {
        var existing = try await database.fetchEnvironmentAssets()
        let curatedIDs = Set(Self.curatedDefaults.map(\.id))

        // Remove bundled assets that are no longer in the curated catalog.
        for staleBundled in existing where staleBundled.sourceType == .bundled && !curatedIDs.contains(staleBundled.id) {
            try await database.deleteEnvironmentAsset(id: staleBundled.id)
        }

        // Remove imported assets whose backing files have been deleted —
        // e.g. after an app reinstall, Application Support wipe, or manual
        // deletion. Without this, the environment list shows orphaned entries
        // that open a blank immersive space.
        existing = try await database.fetchEnvironmentAssets()
        for asset in existing where asset.sourceType == .imported {
            guard !asset.assetPath.hasPrefix("bundle://") else { continue }
            let fileURL = URL(fileURLWithPath: asset.assetPath)
            if !fileManager.fileExists(atPath: fileURL.path) {
                try await database.deleteEnvironmentAsset(id: asset.id)
            }
        }

        existing = try await database.fetchEnvironmentAssets()
        let existingByID = Dictionary(uniqueKeysWithValues: existing.map { ($0.id, $0) })

        for curated in Self.curatedDefaults {
            if let current = existingByID[curated.id] {
                if current.sourceType != .bundled
                    || current.assetPath != curated.assetPath
                    || current.licenseName != curated.licenseName
                    || current.sourceAttributionURL != curated.sourceAttributionURL
                    || current.previewImagePath != curated.previewImagePath {
                    var updated = current
                    updated.sourceType = .bundled
                    updated.assetPath = curated.assetPath
                    updated.licenseName = curated.licenseName
                    updated.sourceAttributionURL = curated.sourceAttributionURL
                    updated.previewImagePath = curated.previewImagePath
                    try await database.saveEnvironmentAsset(updated)
                }
            } else {
                try await database.saveEnvironmentAsset(curated)
            }
        }

        existing = try await database.fetchEnvironmentAssets()
        if !existing.contains(where: { $0.isActive }),
           let defaultAssetID = Self.curatedDefaults.first?.id ?? existing.first?.id {
            try await database.setActiveEnvironmentAsset(id: defaultAssetID)
        }

        // Backfill yaw offsets for any HDRI assets that were imported before
        // the analyzer was added (hdriYawOffset == nil).
        existing = try await database.fetchEnvironmentAssets()
        for asset in existing where asset.hdriYawOffset == nil {
            let ext = URL(fileURLWithPath: asset.assetPath).pathExtension.lowercased()
            guard Self.hdriExtensions.contains(ext) else { continue }
            let fileURL = URL(fileURLWithPath: asset.assetPath)
            guard fileManager.fileExists(atPath: fileURL.path) else { continue }
            let resolvedYawOffset = Self.resolveHdriYawOffset(
                from: await HDRIOrientationAnalyzer.detectScreenYaw(at: fileURL)
            )
            var updated = asset
            updated.hdriYawOffset = resolvedYawOffset
            try await database.saveEnvironmentAsset(updated)
        }

        notifyEnvironmentsChanged()
    }

    func fetchAssets() async throws -> [EnvironmentAsset] {
        try await database.fetchEnvironmentAssets()
    }

    func activeAsset() async throws -> EnvironmentAsset? {
        try await database.fetchActiveEnvironmentAsset()
    }

    /// Returns the first installed asset whose `environmentTag` matches `tag`
    /// (case-insensitive), or `nil` if none is tagged. Used by genre-based
    /// auto-suggestion to resolve a mood to a concrete environment.
    func asset(matchingTag tag: String) async throws -> EnvironmentAsset? {
        let normalized = tag.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !normalized.isEmpty else { return nil }
        let assets = try await database.fetchEnvironmentAssets()
        return assets.first {
            ($0.environmentTag?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()) == normalized
        }
    }

    func activateAsset(id: String) async throws {
        try await database.setActiveEnvironmentAsset(id: id)
        notifyEnvironmentsChanged()
    }

    func importEnvironment(from sourceURL: URL) async throws -> EnvironmentAsset {
        guard fileManager.fileExists(atPath: sourceURL.path) else {
            throw EnvironmentCatalogError.missingFile
        }

        let originalExt = sourceURL.pathExtension
        let normalizedExt = originalExt.lowercased()
        try Self.validateExtension(normalizedExt)
        try Self.validateFileSize(at: sourceURL)

        guard await assetValidator(sourceURL) else {
            throw EnvironmentCatalogError.invalidAsset
        }

        return try await persistImportedAsset(
            sourceURL: sourceURL,
            extension: originalExt,
            preferredName: nil,
            licenseName: "User Imported",
            sourceAttributionURL: nil,
            previewImagePath: nil
        )
    }

    func importCuratedPreset(_ preset: CuratedEnvironmentPreset) async throws -> EnvironmentAsset {
        if let existing = try await database.fetchEnvironmentAssets().first(where: {
            $0.sourceType == .imported
                && $0.name == preset.name
                && $0.sourceAttributionURL == preset.sourceAttributionURL
        }) {
            return existing
        }

        return try await importEnvironment(
            fromRemote: preset.downloadURL,
            preferredName: preset.name,
            licenseName: preset.licenseName,
            sourceAttributionURL: preset.sourceAttributionURL,
            previewImagePath: nil,
            hdriYawOffset: preset.defaultHdriYawOffset
        )
    }

    func importEnvironment(
        fromRemote sourceURL: URL,
        preferredName: String? = nil,
        licenseName: String? = nil,
        sourceAttributionURL: String? = nil,
        previewImagePath: String? = nil,
        hdriYawOffset: Float? = nil
    ) async throws -> EnvironmentAsset {
        let originalExt = sourceURL.pathExtension
        let normalizedExt = originalExt.lowercased()
        try Self.validateExtension(normalizedExt)

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await remoteDataFetcher(sourceURL)
        } catch {
            throw EnvironmentCatalogError.downloadFailed(error.localizedDescription)
        }

        if let httpResponse = response as? HTTPURLResponse,
           !(200...299).contains(httpResponse.statusCode) {
            throw EnvironmentCatalogError.downloadFailed("HTTP \(httpResponse.statusCode)")
        }

        guard !data.isEmpty else {
            throw EnvironmentCatalogError.downloadFailed("No data returned")
        }

        guard EnvironmentImportValidationPolicy.isWithinSizeLimit(data.count) else {
            throw EnvironmentCatalogError.unsupportedFileType
        }

        try fileManager.createDirectory(at: environmentsDirectory, withIntermediateDirectories: true)

        let sourceName = sourceURL.deletingPathExtension().lastPathComponent
        let sanitizedSourceName = sourceName
            .removingPercentEncoding?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            ?? sourceName.trimmingCharacters(in: .whitespacesAndNewlines)
        let temporaryFileNameBase = sanitizedSourceName.isEmpty ? "remote-\(UUID().uuidString)" : "remote-\(UUID().uuidString)-\(sanitizedSourceName)"
        let temporaryFileName = originalExt.isEmpty ? temporaryFileNameBase : "\(temporaryFileNameBase).\(originalExt)"
        let temporaryURL = environmentsDirectory.appendingPathComponent(temporaryFileName)
        try data.write(to: temporaryURL, options: .atomic)
        defer {
            if fileManager.fileExists(atPath: temporaryURL.path) {
                try? fileManager.removeItem(at: temporaryURL)
            }
        }

        guard await assetValidator(temporaryURL) else {
            throw EnvironmentCatalogError.invalidAsset
        }

        return try await persistImportedAsset(
            sourceURL: temporaryURL,
            extension: originalExt,
            sourceNameHint: sourceURL.deletingPathExtension().lastPathComponent,
            preferredName: preferredName,
            licenseName: licenseName,
            sourceAttributionURL: sourceAttributionURL,
            previewImagePath: previewImagePath,
            hdriYawOffset: hdriYawOffset
        )
    }

    private func persistImportedAsset(
        sourceURL: URL,
        extension ext: String,
        sourceNameHint: String? = nil,
        preferredName: String?,
        licenseName: String?,
        sourceAttributionURL: String?,
        previewImagePath: String?,
        hdriYawOffset: Float? = nil
    ) async throws -> EnvironmentAsset {
        try fileManager.createDirectory(at: environmentsDirectory, withIntermediateDirectories: true)

        let id = UUID().uuidString
        let sourceName = sourceNameHint
            ?? sourceURL.deletingPathExtension().lastPathComponent
        let cleanedSourceName = sourceName
            .removingPercentEncoding
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            ?? sourceName.trimmingCharacters(in: .whitespacesAndNewlines)

        let cleanedPreferredName = preferredName?.trimmingCharacters(in: .whitespacesAndNewlines)
        let resolvedName: String
        if let cleanedPreferredName,
           !cleanedPreferredName.isEmpty {
            resolvedName = cleanedPreferredName
        } else if preferredName == nil,
                  !cleanedSourceName.isEmpty {
            resolvedName = cleanedSourceName
        } else {
            let sourcePathName = sourceURL.deletingPathExtension().lastPathComponent
            resolvedName = sourcePathName.isEmpty ? "Imported Environment" : sourcePathName
        }
        let targetFileName = ext.isEmpty ? id : "\(id).\(ext)"
        let targetURL = environmentsDirectory.appendingPathComponent(targetFileName, isDirectory: false)
        if fileManager.fileExists(atPath: targetURL.path) {
            // Use replaceItemAt for atomic replacement, avoiding TOCTOU race.
            _ = try fileManager.replaceItemAt(targetURL, withItemAt: sourceURL)
        } else {
            try fileManager.copyItem(at: sourceURL, to: targetURL)
        }

        // Auto-detect yaw for HDRI files when no explicit offset was provided.
        let resolvedYawOffset: Float?
        if hdriYawOffset == nil, Self.hdriExtensions.contains(ext) {
            resolvedYawOffset = Self.resolveHdriYawOffset(
                from: await HDRIOrientationAnalyzer.detectScreenYaw(at: targetURL)
            )
        } else {
            resolvedYawOffset = hdriYawOffset
        }

        let asset = EnvironmentAsset(
            id: id,
            name: resolvedName,
            sourceType: .imported,
            assetPath: targetURL.path,
            thumbnailPath: nil,
            licenseName: licenseName,
            sourceAttributionURL: sourceAttributionURL,
            previewImagePath: previewImagePath,
            hdriYawOffset: resolvedYawOffset,
            createdAt: Date(),
            isActive: false
        )
        try await database.saveEnvironmentAsset(asset)
        notifyEnvironmentsChanged()
        return asset
    }

    func deleteAsset(id: String) async throws {
        guard let existing = try await database.fetchEnvironmentAssets().first(where: { $0.id == id }) else {
            return
        }

        if existing.sourceType == .imported {
            let fileURL = URL(fileURLWithPath: existing.assetPath)
            if fileManager.fileExists(atPath: fileURL.path) {
                try? fileManager.removeItem(at: fileURL)
            }
        }

        try await database.deleteEnvironmentAsset(id: id)

        if existing.isActive,
           let fallback = try await database.fetchEnvironmentAssets().first {
            try await database.setActiveEnvironmentAsset(id: fallback.id)
        }

        notifyEnvironmentsChanged()
    }

    func immersiveSpaceID(for asset: EnvironmentAsset) -> String {
        if asset.sourceType == .bundled, Self.builtInImmersiveSpaces.contains(asset.assetPath) {
            return asset.assetPath
        }

        let ext = URL(fileURLWithPath: asset.assetPath).pathExtension
        if EnvironmentImportValidationPolicy.routesToHDRISkybox(extension: ext) {
            return "hdriSkybox"
        }

        return "customEnvironment"
    }

    func resolvedAssetURL(for asset: EnvironmentAsset) -> URL? {
        if asset.assetPath.hasPrefix("bundle://") {
            let relative = String(asset.assetPath.dropFirst("bundle://".count))
            return Self.urlInResourceBundle(relativePath: relative)
        }

        let fileURL = URL(fileURLWithPath: asset.assetPath)
        if fileManager.fileExists(atPath: fileURL.path) {
            return fileURL
        }
        return nil
    }

    private static func urlInResourceBundle(relativePath: String) -> URL? {
        let relative = relativePath.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        let parts = relative.split(separator: "/").map(String.init)
        guard let file = parts.last, !file.isEmpty else { return nil }
        let fileURL = URL(fileURLWithPath: file)
        let name = fileURL.deletingPathExtension().lastPathComponent
        let ext = fileURL.pathExtension.isEmpty ? nil : fileURL.pathExtension
        let subdirectory = parts.dropLast().isEmpty ? nil : parts.dropLast().joined(separator: "/")

        return resourceBundle.url(forResource: name, withExtension: ext, subdirectory: subdirectory)
    }

    private static var resourceBundle: Bundle {
        #if SWIFT_PACKAGE
        return .module
        #else
        return .main
        #endif
    }

    private static func defaultAssetValidator(url: URL) async -> Bool {
        let ext = url.pathExtension.lowercased()
        let classification = EnvironmentImportValidationPolicy.classify(extension: ext)
        guard classification != .unsupported else { return false }

        guard FileManager.default.isReadableFile(atPath: url.path) else { return false }

        if ext == "reality" {
            return true
        }

        let resourceValues = try? url.resourceValues(forKeys: [.fileSizeKey])
        let fileSize = resourceValues?.fileSize ?? 0
        guard fileSize > 0 else { return false }
        guard EnvironmentImportValidationPolicy.isWithinSizeLimit(fileSize) else { return false }

        // HDRI / panorama files (HDR, EXR, PNG, JPG) are validated via the image source.
        if case .hdri = classification {
            guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else { return false }
            return CGImageSourceGetCount(source) > 0
        }

        #if os(visionOS)
        do {
            _ = try await Entity(contentsOf: url)
            return true
        } catch {
            return false
        }
        #else
        return true
        #endif
    }

    static func resolveHdriYawOffset(from detectedYaw: Float?) -> Float {
        detectedYaw ?? 0
    }

    private static func validateExtension(_ ext: String) throws {
        guard EnvironmentImportValidationPolicy.isSupportedExtension(ext) else {
            throw EnvironmentCatalogError.unsupportedFileType
        }
    }

    /// Rejects files that exceed the import size cap. Unknown sizes (e.g. unreadable
    /// attributes) are allowed through and validated downstream by the asset validator.
    private static func validateFileSize(at url: URL) throws {
        let resourceValues = try? url.resourceValues(forKeys: [.fileSizeKey])
        let fileSize = resourceValues?.fileSize ?? 0
        guard EnvironmentImportValidationPolicy.isWithinSizeLimit(fileSize) else {
            throw EnvironmentCatalogError.unsupportedFileType
        }
    }

    nonisolated private func notifyEnvironmentsChanged() {
        Task { @MainActor in
            NotificationCenter.default.post(name: .environmentsDidChange, object: nil)
        }
    }
}
