import Foundation

enum SubtitleSettingsPolicy {
    static let defaultLanguage = "en"
    static let defaultAutoSearch = true
    static let defaultFontSize: Double = 24
    static let minFontSize: Double = 16
    static let maxFontSize: Double = 48
    static let defaultOffsetMilliseconds = 0
    static let minOffsetMilliseconds = -5_000
    static let maxOffsetMilliseconds = 5_000

    static func resolvedLanguage(_ storedValue: String?) -> String {
        let trimmed = storedValue?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? defaultLanguage : trimmed
    }

    static func resolvedAutoSearch(_ storedValue: Bool?) -> Bool {
        storedValue ?? defaultAutoSearch
    }

    static func resolvedFontSize(_ storedValue: String?) -> Double {
        guard let storedValue,
              let parsed = Double(storedValue.trimmingCharacters(in: .whitespacesAndNewlines)) else {
            return defaultFontSize
        }

        return max(minFontSize, min(maxFontSize, parsed))
    }

    static func resolvedOffsetMilliseconds(_ storedValue: String?) -> Int {
        guard let storedValue,
              let parsed = Int(storedValue.trimmingCharacters(in: .whitespacesAndNewlines)) else {
            return defaultOffsetMilliseconds
        }

        return max(minOffsetMilliseconds, min(maxOffsetMilliseconds, parsed))
    }

    static func formattedOffset(_ milliseconds: Int) -> String {
        guard milliseconds != 0 else { return "In Sync" }
        let seconds = Double(abs(milliseconds)) / 1_000
        let suffix = milliseconds > 0 ? "late" : "early"
        return String(format: "%.1fs %@", seconds, suffix)
    }
}
