import Foundation

enum IMDbIdentifierPolicy {
    static func normalizedID(from value: String?) -> String? {
        guard let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines),
              trimmed.range(of: #"^tt\d+$"#, options: [.caseInsensitive, .regularExpression]) != nil else {
            return nil
        }
        return trimmed.lowercased()
    }

    static func firstID(in value: String?) -> String? {
        guard let value else { return nil }
        if let direct = normalizedID(from: value) {
            return direct
        }
        guard let match = value.range(
            of: #"tt\d+"#,
            options: [.regularExpression, .caseInsensitive]
        ) else {
            return nil
        }
        return String(value[match]).lowercased()
    }
}
