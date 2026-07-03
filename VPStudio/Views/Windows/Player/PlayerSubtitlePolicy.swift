import Foundation

enum PlayerSubtitlePolicy {
    static func preferredLanguageCodes(from rawValue: String) -> [String] {
        rawValue
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
            .filter { !$0.isEmpty }
    }

    static func automaticSubtitleLanguageCodes(
        configuredLanguageSetting: String?,
        systemPreferredLanguages: [String],
        closedCaptioningEnabled: Bool
    ) -> [String] {
        let configuredCodes = configuredLanguageSetting.map(preferredLanguageCodes(from:)) ?? []
        let systemCodes = systemPreferredLanguages.reduce(into: [String]()) { result, language in
            let normalized = language
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .lowercased()
            guard !normalized.isEmpty else { return }
            let baseCode = normalized
                .split(whereSeparator: { $0 == "-" || $0 == "_" })
                .first
                .map(String.init) ?? normalized
            guard !baseCode.isEmpty, !result.contains(baseCode) else { return }
            result.append(baseCode)
        }

        if closedCaptioningEnabled, !systemCodes.isEmpty {
            return systemCodes + configuredCodes.filter { !systemCodes.contains($0) }
        }

        if !configuredCodes.isEmpty {
            return configuredCodes
        }

        if !systemCodes.isEmpty {
            return systemCodes
        }

        return ["en"]
    }

    static func matchesPreferredLanguage(
        localeIdentifier: String?,
        extendedLanguageTag: String?,
        preferredLanguages: [String]
    ) -> Bool {
        let localeIdentifier = normalizedLanguageTag(localeIdentifier)
        let extendedLanguageTag = normalizedLanguageTag(extendedLanguageTag)

        return preferredLanguages.contains { preferred in
            let normalizedPreferred = normalizedLanguageTag(preferred)
            guard !normalizedPreferred.isEmpty else { return false }
            return languageTag(localeIdentifier, matches: normalizedPreferred)
                || languageTag(extendedLanguageTag, matches: normalizedPreferred)
        }
    }

    static func subtitleSearchQuery(from fileName: String) -> String {
        let trimmed = fileName.trimmingCharacters(in: .whitespacesAndNewlines)
        let withoutExtension = (trimmed as NSString).deletingPathExtension
        let cleaned = withoutExtension.replacingOccurrences(
            of: "[._]+",
            with: " ",
            options: .regularExpression
        )
        return cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func mediaTrackDisplayName(
        fallback: String?,
        name: String?,
        description: String?,
        index: Int,
        kind: String
    ) -> String {
        for candidate in [fallback, name, description] {
            let cleaned = candidate?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            if !cleaned.isEmpty {
                return cleaned
            }
        }
        return "\(kind) \(index + 1)"
    }

    private static func normalizedLanguageTag(_ value: String?) -> String {
        (value ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .replacingOccurrences(of: "_", with: "-")
    }

    private static func languageTag(_ tag: String, matches preferred: String) -> Bool {
        tag == preferred || tag.hasPrefix("\(preferred)-")
    }
}
