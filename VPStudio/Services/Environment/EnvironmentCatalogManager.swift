import Foundation
import ImageIO
import os
#if os(visionOS)
import RealityKit
#endif

private final class EnvironmentCatalogRemoteSessionDelegate: NSObject, URLSessionTaskDelegate, @unchecked Sendable {
    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        willPerformHTTPRedirection response: HTTPURLResponse,
        newRequest request: URLRequest,
        completionHandler: @escaping (URLRequest?) -> Void
    ) {
        completionHandler(EnvironmentCatalogManager.validatedRemoteRedirectRequest(request))
    }
}

enum EnvironmentCatalogError: LocalizedError {
    case unsupportedFileType
    case missingFile
    case invalidAsset
    case downloadFailed(String)

    var errorDescription: String? {
        switch self {
        case .unsupportedFileType:
            return "Unsupported environment file type. Use \(EnvironmentImportValidationPolicy.supportedExtensionDisplayList) files."
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
    private static let defaultRemoteSessionDelegate = EnvironmentCatalogRemoteSessionDelegate()
    private static let defaultRemoteSession: URLSession = {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 30
        configuration.timeoutIntervalForResource = 300
        return URLSession(
            configuration: configuration,
            delegate: defaultRemoteSessionDelegate,
            delegateQueue: nil
        )
    }()

    private let database: DatabaseManager
    private let fileManager: FileManager
    private nonisolated let environmentsDirectory: URL
    private let assetValidator: @Sendable (URL) async -> Bool
    private let remoteDataFetcher: RemoteDataFetcher

    private static let supportedExtensions: Set<String> = EnvironmentImportValidationPolicy.supportedExtensions

    private static let hdriExtensions: Set<String> = EnvironmentImportValidationPolicy.hdriExtensions
    private static let maximumEnvironmentDisplayNameLength = 80
    private static let fallbackImportedEnvironmentName = "Imported Environment"

    /// Stable id for the bundled SkyDome environment shipped in `Resources/Environments`.
    /// Used by `bootstrapCuratedAssets()` so a fresh install has at least one activatable
    /// immersive environment out of the box.
    static let bundledSkyDomeID = "builtin-skydome"

    /// `bundle://` path for the bundled SkyDome USDZ. `.process("Resources")` flattens
    /// nested resource directories, so the asset lands at the bundle root (no subdirectory)
    /// — matching how `urlInResourceBundle(relativePath:)` resolves it.
    static let bundledSkyDomeAssetPath = "bundle://SkyDome.usdz"
    static let bundledSkyDomePreviewPath = "bundle://SkyDomePreview.png"

    private static let curatedDefaults: [EnvironmentAsset] = [
        EnvironmentAsset(
            id: bundledSkyDomeID,
            name: "Sky Dome",
            sourceType: .bundled,
            assetPath: bundledSkyDomeAssetPath,
            thumbnailPath: nil,
            licenseName: "CC0 1.0 Universal",
            sourceAttributionURL: nil,
            previewImagePath: bundledSkyDomePreviewPath,
            hdriYawOffset: nil,
            // Resolves the neutral/cinema mood so genre auto-suggestion always has a
            // concrete installed environment to fall back to on a fresh install.
            environmentTag: GenreEnvironmentSuggestionPolicy.neutralDefault.matchKey,
            isActive: false
        ),
    ]

    /// Validated URL from a hardcoded string.
    private static func presetURL(_ string: String) -> URL? {
        guard let url = EnvironmentURLPolicy.webURL(from: string, requiresHTTPS: true) else {
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
        defaultHdriYawOffset: Float? = nil,
        defaultEnvironmentTag: String? = nil
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
            defaultHdriYawOffset: defaultHdriYawOffset,
            defaultEnvironmentTag: defaultEnvironmentTag
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
            licenseName: "CC0 1.0 Universal",
            defaultEnvironmentTag: GenreEnvironmentSuggestionPolicy.neutralDefault.matchKey
        ),
        preset(
            id: "polyhaven-cinema-hall",
            name: "Cinema Hall",
            description: "Grand cinema auditorium with atmospheric house lights. CC0 HDRI panorama.",
            provider: .polyHaven,
            downloadURLString: "https://dl.polyhaven.org/file/ph-assets/HDRIs/hdr/4k/cinema_hall_4k.hdr",
            sourceAttributionURL: "https://polyhaven.com/a/cinema_hall",
            licenseName: "CC0 1.0 Universal",
            defaultEnvironmentTag: GenreEnvironmentSuggestionPolicy.neutralDefault.matchKey
        ),
    ].compactMap { $0 }

    private static let builtInImmersiveSpaces: Set<String> = []

    nonisolated static var onlinePresets: [CuratedEnvironmentPreset] {
        curatedRemotePresets
    }

    nonisolated var managedImportedAssetsDirectory: URL {
        environmentsDirectory
    }

    private static func defaultRemoteDataFetcher(url: URL) async throws -> (Data, URLResponse) {
        let (bytes, response) = try await defaultRemoteSession.bytes(from: url)
        try rejectOversizeRemoteResponse(response)

        var data = Data()
        if response.expectedContentLength > 0,
           response.expectedContentLength <= Int64(Int.max) {
            data.reserveCapacity(Int(response.expectedContentLength))
        }
        for try await byte in bytes {
            data.append(byte)
            guard EnvironmentImportValidationPolicy.isWithinSizeLimit(data.count) else {
                throw EnvironmentCatalogError.unsupportedFileType
            }
        }
        return (data, response)
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
            try await deleteAsset(id: staleBundled.id)
        }

        // Remove imported assets whose backing files have been deleted —
        // e.g. after an app reinstall, Application Support wipe, or manual
        // deletion. Without this, the environment list shows orphaned entries
        // that open a blank immersive space.
        existing = try await database.fetchEnvironmentAssets()
        for asset in existing where asset.sourceType == .imported {
            guard !asset.assetPath.hasPrefix("bundle://") else { continue }
            guard let fileURL = managedImportedAssetURL(for: asset) else {
                try await deleteAsset(id: asset.id)
                continue
            }
            if !fileManager.fileExists(atPath: fileURL.path) {
                try await deleteAsset(id: asset.id)
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
                    || current.previewImagePath != curated.previewImagePath
                    || current.environmentTag != curated.environmentTag {
                    var updated = current
                    updated.sourceType = .bundled
                    updated.assetPath = curated.assetPath
                    updated.licenseName = curated.licenseName
                    updated.sourceAttributionURL = curated.sourceAttributionURL
                    updated.previewImagePath = curated.previewImagePath
                    updated.environmentTag = curated.environmentTag
                    try await database.saveEnvironmentAsset(updated)
                }
            } else {
                try await database.saveEnvironmentAsset(curated)
            }
        }

        existing = try await database.fetchEnvironmentAssets()
        let preferredEnvironmentID = try await database.getSetting(key: SettingsKeys.preferredEnvironment)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let hasPreferredEnvironment = preferredEnvironmentID?.isEmpty == false
        if !hasPreferredEnvironment,
           existing.contains(where: { $0.id == Self.bundledSkyDomeID && $0.isActive }) {
            try await database.clearActiveEnvironmentAsset()
        }

        // Backfill yaw offsets for any HDRI assets that were imported before
        // the analyzer was added (hdriYawOffset == nil).
        existing = try await database.fetchEnvironmentAssets()
        for asset in existing where asset.hdriYawOffset == nil {
            let ext = URL(fileURLWithPath: asset.assetPath).pathExtension.lowercased()
            guard Self.hdriExtensions.contains(ext) else { continue }
            guard let fileURL = managedImportedAssetURL(for: asset) else { continue }
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

    @discardableResult
    func activateAsset(id: String) async throws -> Bool {
        guard try await database.setActiveEnvironmentAsset(id: id) else { return false }
        try await database.setSetting(key: SettingsKeys.activeEnvironmentSelectionCleared, value: nil)
        try await database.setSetting(key: SettingsKeys.preferredEnvironment, value: id)
        notifyEnvironmentsChanged()
        return true
    }

    func clearActiveAsset() async throws {
        try await database.clearActiveEnvironmentAsset()
        try await database.setSetting(key: SettingsKeys.activeEnvironmentSelectionCleared, value: "1")
        try await database.setSetting(key: SettingsKeys.preferredEnvironment, value: nil)
        notifyEnvironmentsChanged()
    }

    func importEnvironment(from sourceURL: URL) async throws -> EnvironmentAsset {
        guard sourceURL.isFileURL else {
            throw EnvironmentCatalogError.missingFile
        }

        guard fileManager.fileExists(atPath: sourceURL.path) else {
            throw EnvironmentCatalogError.missingFile
        }

        guard Self.isImportableRegularFile(sourceURL) else {
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
            hdriYawOffset: preset.defaultHdriYawOffset,
            environmentTag: preset.defaultEnvironmentTag
        )
    }

    func importEnvironment(
        fromRemote sourceURL: URL,
        preferredName: String? = nil,
        licenseName: String? = nil,
        sourceAttributionURL: String? = nil,
        previewImagePath: String? = nil,
        hdriYawOffset: Float? = nil,
        environmentTag: String? = nil
    ) async throws -> EnvironmentAsset {
        guard let validatedSourceURL = EnvironmentURLPolicy.webURL(
            from: sourceURL.absoluteString,
            requiresHTTPS: true
        ) else {
            throw EnvironmentCatalogError.downloadFailed("Only HTTPS environment downloads are supported.")
        }
        try Self.validateRemoteSourceExtensionIfPresent(validatedSourceURL)

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await remoteDataFetcher(validatedSourceURL)
        } catch let error as EnvironmentCatalogError {
            throw error
        } catch {
            throw EnvironmentCatalogError.downloadFailed(error.localizedDescription)
        }

        if let httpResponse = response as? HTTPURLResponse,
           !(200...299).contains(httpResponse.statusCode) {
            throw EnvironmentCatalogError.downloadFailed("HTTP \(httpResponse.statusCode)")
        }

        let finalResponseURL = try Self.validatedRemoteResponseURL(
            response,
            fallbackURL: validatedSourceURL
        )
        try Self.rejectOversizeRemoteResponse(response)
        let resolvedExt = try Self.resolvedRemoteExtension(
            sourceURL: finalResponseURL,
            response: response
        )

        guard !data.isEmpty else {
            throw EnvironmentCatalogError.downloadFailed("No data returned")
        }

        guard EnvironmentImportValidationPolicy.isWithinSizeLimit(data.count) else {
            throw EnvironmentCatalogError.unsupportedFileType
        }

        try fileManager.createDirectory(at: environmentsDirectory, withIntermediateDirectories: true)

        let sourceName = validatedSourceURL.deletingPathExtension().lastPathComponent
        let sanitizedSourceName = Self.sanitizedEnvironmentDisplayName(from: sourceName)
        let temporaryFileNameBase = sanitizedSourceName.map {
            "remote-\(UUID().uuidString)-\($0)"
        } ?? "remote-\(UUID().uuidString)"
        let temporaryFileName = "\(temporaryFileNameBase).\(resolvedExt)"
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
            extension: resolvedExt,
            sourceNameHint: validatedSourceURL.deletingPathExtension().lastPathComponent,
            preferredName: preferredName,
            licenseName: licenseName,
            sourceAttributionURL: sourceAttributionURL,
            previewImagePath: previewImagePath,
            hdriYawOffset: hdriYawOffset,
            environmentTag: environmentTag
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
        hdriYawOffset: Float? = nil,
        environmentTag: String? = nil
    ) async throws -> EnvironmentAsset {
        try fileManager.createDirectory(at: environmentsDirectory, withIntermediateDirectories: true)

        let id = UUID().uuidString
        let sourceName = sourceNameHint
            ?? sourceURL.deletingPathExtension().lastPathComponent
        let cleanedSourceName = Self.sanitizedEnvironmentDisplayName(from: sourceName)
        let cleanedPreferredName = Self.sanitizedEnvironmentDisplayName(from: preferredName)
        let cleanedFallbackName = Self.sanitizedEnvironmentDisplayName(
            from: sourceURL.deletingPathExtension().lastPathComponent
        )
        let resolvedName: String
        if let cleanedPreferredName {
            resolvedName = cleanedPreferredName
        } else if let cleanedSourceName {
            resolvedName = cleanedSourceName
        } else {
            resolvedName = cleanedFallbackName ?? Self.fallbackImportedEnvironmentName
        }
        let normalizedExt = EnvironmentImportValidationPolicy.normalizedExtension(for: ext)
        let targetFileName = normalizedExt.isEmpty ? id : "\(id).\(normalizedExt)"
        let targetURL = environmentsDirectory.appendingPathComponent(targetFileName, isDirectory: false)
        if fileManager.fileExists(atPath: targetURL.path) {
            // Use replaceItemAt for atomic replacement, avoiding TOCTOU race.
            _ = try fileManager.replaceItemAt(targetURL, withItemAt: sourceURL)
        } else {
            try fileManager.copyItem(at: sourceURL, to: targetURL)
        }

        // Auto-detect yaw for HDRI files when no explicit offset was provided.
        let resolvedYawOffset: Float?
        if hdriYawOffset == nil, Self.hdriExtensions.contains(normalizedExt) {
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
            licenseName: Self.sanitizedOptionalMetadataText(licenseName),
            sourceAttributionURL: Self.sanitizedSourceAttributionURL(sourceAttributionURL),
            previewImagePath: sanitizedPreviewImagePath(previewImagePath),
            hdriYawOffset: resolvedYawOffset,
            environmentTag: environmentTag,
            createdAt: Date(),
            isActive: false
        )
        try await database.saveEnvironmentAsset(asset)
        notifyEnvironmentsChanged()
        return asset
    }

    private static func sanitizedEnvironmentDisplayName(from value: String?) -> String? {
        guard let rawValue = value else { return nil }
        let decodedValue = rawValue.removingPercentEncoding ?? rawValue
        let separators = CharacterSet.whitespacesAndNewlines
            .union(.controlCharacters)
            .union(CharacterSet(charactersIn: "/\\:"))
        let collapsedName = decodedValue
            .components(separatedBy: separators)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !collapsedName.isEmpty else { return nil }

        let cappedName = String(collapsedName.prefix(maximumEnvironmentDisplayNameLength))
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return cappedName.isEmpty ? nil : cappedName
    }

    private static func sanitizedOptionalMetadataText(_ value: String?) -> String? {
        guard let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines),
              !trimmed.isEmpty else {
            return nil
        }
        return trimmed
    }

    private static func sanitizedSourceAttributionURL(_ value: String?) -> String? {
        EnvironmentURLPolicy.webURL(from: value, requiresHTTPS: true)?.absoluteString
    }

    private func sanitizedPreviewImagePath(_ value: String?) -> String? {
        guard let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines),
              !trimmed.isEmpty else {
            return nil
        }

        if trimmed.hasPrefix("bundle://") {
            let relativePath = String(trimmed.dropFirst("bundle://".count))
            guard Self.urlInResourceBundle(relativePath: relativePath) != nil else {
                return nil
            }
            return "bundle://\(relativePath.trimmingCharacters(in: CharacterSet(charactersIn: "/")))"
        }

        guard let fileURL = EnvironmentURLPolicy.absoluteFileURL(fromStoredPath: trimmed),
              EnvironmentURLPolicy.fileURL(fileURL, isInside: environmentsDirectory) else {
            return nil
        }
        return fileURL.standardizedFileURL.path
    }

    func deleteAsset(id: String) async throws {
        guard let existing = try await database.fetchEnvironmentAssets().first(where: { $0.id == id }) else {
            return
        }

        if existing.sourceType == .imported,
           let fileURL = managedImportedAssetURL(for: existing) {
            if fileManager.fileExists(atPath: fileURL.path) {
                try? fileManager.removeItem(at: fileURL)
            }
        }

        try await database.deleteEnvironmentAsset(id: id)

        if existing.isActive {
            try await database.clearActiveEnvironmentAsset()
            try await database.setSetting(key: SettingsKeys.activeEnvironmentSelectionCleared, value: "1")
            try await database.setSetting(key: SettingsKeys.preferredEnvironment, value: nil)
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

        guard let fileURL = managedImportedAssetURL(for: asset) else {
            return nil
        }
        if fileManager.fileExists(atPath: fileURL.path) {
            return fileURL
        }
        return nil
    }

    private func managedImportedAssetURL(for asset: EnvironmentAsset) -> URL? {
        guard asset.sourceType == .imported,
              let fileURL = EnvironmentURLPolicy.absoluteFileURL(fromStoredPath: asset.assetPath),
              EnvironmentURLPolicy.fileURL(fileURL, isInside: environmentsDirectory) else {
            return nil
        }

        return fileURL.standardizedFileURL
    }

    private static func urlInResourceBundle(relativePath: String) -> URL? {
        EnvironmentURLPolicy.bundleResourceURL(relativePath: relativePath, in: resourceBundle)
    }

    private static func validatedRemoteResponseURL(
        _ response: URLResponse,
        fallbackURL: URL
    ) throws -> URL {
        let finalURL = response.url ?? fallbackURL
        guard let validatedURL = EnvironmentURLPolicy.webURL(
            from: finalURL.absoluteString,
            requiresHTTPS: true
        ) else {
            throw EnvironmentCatalogError.downloadFailed("Only HTTPS environment downloads are supported.")
        }
        return validatedURL
    }

    nonisolated static func validatedRemoteRedirectRequest(_ request: URLRequest) -> URLRequest? {
        guard let url = request.url,
              let validatedURL = EnvironmentURLPolicy.webURL(
                from: url.absoluteString,
                requiresHTTPS: true
              ) else {
            return nil
        }

        do {
            try validateRemoteSourceExtensionIfPresent(validatedURL)
            return request
        } catch {
            return nil
        }
    }

    private static func validateRemoteSourceExtensionIfPresent(_ sourceURL: URL) throws {
        let ext = sourceURL.pathExtension.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !ext.isEmpty else { return }
        try validateExtension(ext)
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

        let resourceValues = try? url.resourceValues(forKeys: [.fileSizeKey])
        let fileSize = resourceValues?.fileSize ?? 0
        guard fileSize > 0 else { return false }
        guard EnvironmentImportValidationPolicy.isWithinSizeLimit(fileSize) else { return false }

        // HDRI / panorama files (HDR, EXR, PNG, JPG, JPEG) are validated via the image source.
        if case .hdri = classification {
            guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else { return false }
            guard CGImageSourceGetCount(source) > 0 else { return false }
            guard imageSourceHasPanoramaAspectRatio(source) else { return false }
            return imageSourceCreatesValidationThumbnail(source)
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

    private static func imageSourceHasPanoramaAspectRatio(_ source: CGImageSource) -> Bool {
        guard let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any] else {
            return false
        }
        let width = pixelDimension(properties[kCGImagePropertyPixelWidth])
        let height = pixelDimension(properties[kCGImagePropertyPixelHeight])
        return EnvironmentImportValidationPolicy.hasUsablePanoramaDimensions(
            width: width ?? 0,
            height: height ?? 0
        )
    }

    private static func pixelDimension(_ value: Any?) -> Int? {
        if let value = value as? Int {
            return value
        }
        if let value = value as? NSNumber {
            return value.intValue
        }
        return nil
    }

    private static func imageSourceCreatesValidationThumbnail(_ source: CGImageSource) -> Bool {
        let options: [CFString: Any] = [
            kCGImageSourceShouldCache: false,
            kCGImageSourceShouldAllowFloat: false,
            kCGImageSourceThumbnailMaxPixelSize: 64,
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
        ]
        return CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) != nil
    }

    static func resolveHdriYawOffset(from detectedYaw: Float?) -> Float {
        detectedYaw ?? 0
    }

    private static func validateExtension(_ ext: String) throws {
        guard EnvironmentImportValidationPolicy.isSupportedExtension(ext) else {
            throw EnvironmentCatalogError.unsupportedFileType
        }
    }

    private static func resolvedRemoteExtension(sourceURL: URL, response: URLResponse) throws -> String {
        let urlExt = normalizedSupportedExtension(sourceURL.pathExtension)
        let suggestedExt = normalizedSupportedExtension(response.suggestedFilename)
        let mimeExt = try normalizedRemoteMIMEExtension(
            response.mimeType,
            treatsUnsupportedAsAbsent: !hasExplicitContentType(response)
        )

        if let urlExt {
            try validateRemoteExtension(urlExt, isCompatibleWith: mimeExt)
            return urlExt
        }

        if let suggestedExt {
            try validateRemoteExtension(suggestedExt, isCompatibleWith: mimeExt)
            return suggestedExt
        }

        guard let mimeExt else {
            throw EnvironmentCatalogError.unsupportedFileType
        }
        return mimeExt
    }

    private static func normalizedSupportedExtension(_ rawValue: String?) -> String? {
        guard let rawValue else { return nil }
        let ext = URL(fileURLWithPath: rawValue).pathExtension.isEmpty
            ? rawValue
            : URL(fileURLWithPath: rawValue).pathExtension
        let normalized = EnvironmentImportValidationPolicy.normalizedExtension(for: ext)
        return EnvironmentImportValidationPolicy.isSupportedExtension(normalized) ? normalized : nil
    }

    private static func normalizedRemoteMIMEExtension(
        _ rawMIMEType: String?,
        treatsUnsupportedAsAbsent: Bool
    ) throws -> String? {
        guard let rawMIMEType else { return nil }
        let mimeType = rawMIMEType
            .split(separator: ";", maxSplits: 1, omittingEmptySubsequences: true)
            .first
            .map(String.init)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        guard let mimeType, !mimeType.isEmpty else { return nil }

        switch mimeType {
        case "application/octet-stream", "binary/octet-stream":
            return nil
        case "image/vnd.radiance", "image/x-hdr", "application/radiance":
            return "hdr"
        case "image/exr", "image/x-exr", "image/x-openexr", "application/x-exr":
            return "exr"
        case "image/png":
            return "png"
        case "image/jpeg", "image/jpg":
            return "jpg"
        case "model/vnd.usdz+zip", "application/vnd.usdz+zip", "model/usd", "application/x-usdz":
            return "usdz"
        case "model/vnd.reality", "application/vnd.apple.reality", "application/x-reality":
            return "reality"
        default:
            if treatsUnsupportedAsAbsent {
                return nil
            }
            throw EnvironmentCatalogError.unsupportedFileType
        }
    }

    private static func hasExplicitContentType(_ response: URLResponse) -> Bool {
        guard let httpResponse = response as? HTTPURLResponse else {
            return response.mimeType?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
        }
        guard let contentType = httpResponse.value(forHTTPHeaderField: "Content-Type") else {
            return false
        }
        return !contentType.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private static func validateRemoteExtension(_ ext: String, isCompatibleWith mimeExt: String?) throws {
        guard let mimeExt else { return }
        guard remoteExtensionsAreCompatible(ext, mimeExt) else {
            throw EnvironmentCatalogError.unsupportedFileType
        }
    }

    private static func remoteExtensionsAreCompatible(_ lhs: String, _ rhs: String) -> Bool {
        if lhs == rhs { return true }
        return Set([lhs, rhs]).isSubset(of: ["jpg", "jpeg"])
    }

    private static func rejectOversizeRemoteResponse(_ response: URLResponse) throws {
        guard response.expectedContentLength > Int64(EnvironmentImportValidationPolicy.maxFileSizeBytes) else {
            return
        }
        throw EnvironmentCatalogError.unsupportedFileType
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

    private static func isImportableRegularFile(_ url: URL) -> Bool {
        guard let resourceValues = try? url.resourceValues(forKeys: [
            .isRegularFileKey,
            .isSymbolicLinkKey,
            .isDirectoryKey,
        ]) else {
            return false
        }

        return resourceValues.isRegularFile == true
            && resourceValues.isSymbolicLink != true
            && resourceValues.isDirectory != true
    }

    nonisolated private func notifyEnvironmentsChanged() {
        Task { @MainActor in
            NotificationCenter.default.post(name: .environmentsDidChange, object: nil)
        }
    }
}
