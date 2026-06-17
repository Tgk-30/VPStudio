import Foundation

/// Pure parsing for scene/p2p release-name metadata that the `MediaType` enums do
/// not already cover. Quality / codec / HDR / audio / source live on the
/// `VideoQuality` / `VideoCodec` / `HDRFormat` / `AudioFormat` / `SourceType` enums —
/// this type only extracts the trailing release group, which those enums do not parse.
enum ReleaseNameParser {
    /// Extracts the trailing release-group token from a scene/p2p release name.
    ///
    /// Release names conventionally end with `-GROUP` (e.g. `Movie.2024.1080p.BluRay.x265-RARBG`
    /// → `RARBG`). This is robust to:
    /// - file extensions appended after the group (`...-RARBG.mkv` → `RARBG`),
    /// - bracketed junk / scene tags trailing the group (`...-RARBG [eztv]` → `RARBG`),
    /// - surrounding whitespace and newlines.
    ///
    /// Returns `nil` when no plausible group token is present (no trailing `-token`,
    /// dotted-only names, or a token that looks like quality/codec/year metadata
    /// rather than a group).
    nonisolated static func releaseGroup(from title: String) -> String? {
        var working = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !working.isEmpty else { return nil }

        // Use only the first line — multi-line titles carry mirror/quality notes below.
        if let firstLine = working.split(whereSeparator: \.isNewline).first {
            working = String(firstLine).trimmingCharacters(in: .whitespacesAndNewlines)
        }

        // Strip trailing bracketed junk, e.g. " [eztv]", " (RARBG)", repeatedly.
        working = strippingTrailingBracketedSegments(from: working)

        // Strip a single trailing file extension, e.g. ".mkv", ".mp4".
        working = strippingTrailingExtension(from: working)

        guard let dashIndex = working.lastIndex(of: "-") else { return nil }

        let candidate = working[working.index(after: dashIndex)...]
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard isPlausibleGroup(candidate) else { return nil }
        return candidate
    }

    // MARK: - Helpers

    private static let bracketPairs: [(open: Character, close: Character)] = [
        ("[", "]"),
        ("(", ")"),
        ("{", "}"),
    ]

    private static func strippingTrailingBracketedSegments(from value: String) -> String {
        var result = value
        var didStrip = true
        while didStrip {
            didStrip = false
            let trimmed = result.trimmingCharacters(in: .whitespacesAndNewlines)
            guard let last = trimmed.last else { break }

            for pair in bracketPairs where last == pair.close {
                if let openIndex = trimmed.lastIndex(of: pair.open), openIndex < trimmed.index(before: trimmed.endIndex) {
                    result = String(trimmed[..<openIndex])
                    didStrip = true
                }
                break
            }
        }
        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func strippingTrailingExtension(from value: String) -> String {
        let knownExtensions: Set<String> = [
            "mkv", "mp4", "avi", "mov", "m4v", "wmv", "flv", "webm", "ts", "m2ts",
        ]
        guard let dotIndex = value.lastIndex(of: "."), dotIndex < value.index(before: value.endIndex) else {
            return value
        }
        let ext = value[value.index(after: dotIndex)...].lowercased()
        guard knownExtensions.contains(ext) else { return value }
        return String(value[..<dotIndex]).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// A plausible release group is a short alphanumeric token that is not obviously
    /// quality/codec/year metadata. Embedded `.`/space (e.g. a sentence fragment) and
    /// purely numeric tokens (years, episode counts) are rejected.
    private static func isPlausibleGroup(_ candidate: String) -> Bool {
        guard !candidate.isEmpty, candidate.count <= 24 else { return false }

        // Groups are single tokens — reject anything with internal whitespace or dots.
        guard !candidate.contains(where: { $0.isWhitespace || $0 == "." }) else { return false }

        // Must contain at least one letter; reject pure numbers (years, counts).
        guard candidate.contains(where: { $0.isLetter }) else { return false }

        // Allow only word-ish characters (letters, digits, ampersand) so trailing
        // punctuation noise does not get mistaken for a group.
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "&"))
        guard candidate.unicodeScalars.allSatisfy({ allowed.contains($0) }) else { return false }

        // Reject the trailing half of common hyphenated source/codec/container tokens
        // (WEB-DL, BLU-RAY, HEVC-DV, etc.) — these are not release groups, and lastIndex(of:"-")
        // would otherwise surface bogus "DL"/"RAY"/"DV" group badges on no-group releases.
        let sourceCodecStopList: Set<String> = [
            "DL", "RAY", "DV", "HD", "RIP", "DTS", "HEVC", "AVC", "DDP", "DD", "EAC3", "AC3",
            "TV", "CAM", "TS", "HDR", "SDR", "REMUX", "WEBRIP", "WEB", "BDRIP", "DVDRIP"
        ]
        guard !sourceCodecStopList.contains(candidate.uppercased()) else { return false }

        return true
    }
}
