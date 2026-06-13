import Foundation

/// Parses subtitle files into timed cue arrays for rendering
struct SubtitleParser {

    struct SubtitleCue: Sendable, Identifiable {
        let id: Int
        let startTime: TimeInterval
        let endTime: TimeInterval
        let text: String
    }

    // MARK: - Parse by Format

    static func parse(content: String, format: SubtitleFormat) -> [SubtitleCue] {
        let normalizedContent = normalizeNewlines(content)
        switch format {
        case .srt: return parseSRT(normalizedContent)
        case .vtt: return parseVTT(normalizedContent)
        case .ass, .ssa: return parseASS(normalizedContent)
        case .unknown: return parseSRT(normalizedContent) // best-effort fallback
        }
    }

    /// Get the active cue at a given time
    static func activeCue(at time: TimeInterval, in cues: [SubtitleCue]) -> SubtitleCue? {
        cues.first { $0.startTime <= time && $0.endTime >= time }
    }

    // MARK: - SRT Parser

    static func parseSRT(_ content: String) -> [SubtitleCue] {
        let normalizedContent = normalizeNewlines(content)
        var cues: [SubtitleCue] = []
        var block: [String] = []

        func parseBlock(_ lines: [String]) {
            guard lines.count >= 2 else { return }

            let indexLine = lines[0].trimmingCharacters(in: .whitespacesAndNewlines)
            let timeLine = lines[1].trimmingCharacters(in: .whitespacesAndNewlines)
            guard !indexLine.isEmpty,
                  let index = Int(indexLine) else {
                return
            }

            // Line 1: timestamp
            let timeParts = timeLine.components(separatedBy: " --> ")
            guard timeParts.count == 2,
                  let start = parseSRTTime(timeParts[0].trimmingCharacters(in: .whitespaces)),
                  let end = parseSRTTime(timeParts[1].trimmingCharacters(in: .whitespaces)) else {
                return
            }
            let (orderedStart, orderedEnd) = orderedTimes(start: start, end: end)

            // Lines 2+: text (including empty/whitespace-only lines).
            let text = lines.dropFirst(2).joined(separator: "\n")
                .replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)

            cues.append(SubtitleCue(id: index, startTime: orderedStart, endTime: orderedEnd, text: text))
        }

        let lines = normalizedContent.components(separatedBy: "\n")
        for line in lines {
            if line.isEmpty {
                parseBlock(block)
                block.removeAll(keepingCapacity: true)
            } else {
                block.append(line)
            }
        }
        parseBlock(block)

        return cues
    }

    // MARK: - VTT Parser

    static func parseVTT(_ content: String) -> [SubtitleCue] {
        let normalizedContent = normalizeNewlines(content)
        var cues: [SubtitleCue] = []
        // Skip WEBVTT header
        let stripped = normalizedContent.replacingOccurrences(of: "^WEBVTT[^\n]*\n", with: "", options: .regularExpression)
        let blocks = stripped.components(separatedBy: "\n\n")
        var index = 0

        for block in blocks {
            let lines = block.trimmingCharacters(in: .whitespacesAndNewlines).components(separatedBy: "\n")
            guard lines.count >= 2 else { continue }

            // Find timestamp line
            guard let timeLineIdx = lines.firstIndex(where: { $0.contains("-->") }) else { continue }

            let timeParts = lines[timeLineIdx].components(separatedBy: " --> ")
            guard timeParts.count == 2,
                  let start = parseVTTTime(timeParts[0].trimmingCharacters(in: .whitespaces)),
                  let end = parseVTTTime(timeParts[1].components(separatedBy: " ").first?.trimmingCharacters(in: .whitespaces) ?? "") else { continue }
            let (orderedStart, orderedEnd) = orderedTimes(start: start, end: end)

            let textLines = lines[(timeLineIdx + 1)...]
            let text = stripVTTMarkup(from: textLines.joined(separator: "\n"))

            index += 1
            cues.append(SubtitleCue(id: index, startTime: orderedStart, endTime: orderedEnd, text: text))
        }

        return cues
    }

    // MARK: - ASS/SSA Parser

    static func parseASS(_ content: String) -> [SubtitleCue] {
        var cues: [SubtitleCue] = []
        var index = 0
        let lines = content.components(separatedBy: "\n")

        for line in lines {
            guard line.hasPrefix("Dialogue:") else { continue }
            let parts = line.dropFirst("Dialogue:".count)
                .trimmingCharacters(in: .whitespaces)
                .components(separatedBy: ",")
            guard parts.count >= 10 else { continue }

            guard let start = parseASSTime(parts[1].trimmingCharacters(in: .whitespaces)),
                  let end = parseASSTime(parts[2].trimmingCharacters(in: .whitespaces)) else { continue }
            let (orderedStart, orderedEnd) = orderedTimes(start: start, end: end)

            // Text is everything from field 9 onwards (may contain commas)
            let text = parts[9...].joined(separator: ",")
                .replacingOccurrences(of: "\\{[^}]+\\}", with: "", options: .regularExpression) // Strip ASS tags
                .replacingOccurrences(of: "\\N", with: "\n")
                .replacingOccurrences(of: "\\n", with: "\n")

            index += 1
            cues.append(SubtitleCue(id: index, startTime: orderedStart, endTime: orderedEnd, text: text))
        }

        return cues.sorted { $0.startTime < $1.startTime }
    }

    // MARK: - Time Parsing

    private static func parseSRTTime(_ str: String) -> TimeInterval? {
        // 00:01:23,456
        let clean = str.replacingOccurrences(of: ",", with: ".")
        return parseColonTime(clean)
    }

    private static func parseVTTTime(_ str: String) -> TimeInterval? {
        // 00:01:23.456 or 01:23.456
        parseColonTime(str)
    }

    private static func parseASSTime(_ str: String) -> TimeInterval? {
        // 0:01:23.45
        parseColonTime(str)
    }

    private static func parseColonTime(_ str: String) -> TimeInterval? {
        let parts = str.components(separatedBy: ":")
        guard parts.count >= 2 else { return nil }
        guard parts.allSatisfy({ !$0.hasPrefix("-") }) else { return nil }

        if parts.count == 3 {
            guard let h = Double(parts[0]),
                  let m = Double(parts[1]),
                  let s = Double(parts[2]),
                  h >= 0,
                  m >= 0,
                  s >= 0 else { return nil }
            return h * 3600 + m * 60 + s
        } else {
            guard let m = Double(parts[0]),
                  let s = Double(parts[1]),
                  m >= 0,
                  s >= 0 else { return nil }
            return m * 60 + s
        }
    }

    private static func orderedTimes(start: TimeInterval, end: TimeInterval) -> (TimeInterval, TimeInterval) {
        guard end < start else { return (start, end) }
        return (end, start)
    }

    private static func stripVTTMarkup(from text: String) -> String {
        var result = ""
        var index = text.startIndex

        while index < text.endIndex {
            guard text[index] == "<" else {
                result.append(text[index])
                index = text.index(after: index)
                continue
            }

            let afterOpenBracket = text.index(after: index)
            let closingRange = text[afterOpenBracket..<text.endIndex].range(of: ">")
            guard let closingRange else {
                result.append("<")
                index = afterOpenBracket
                continue
            }

            let tag = String(text[afterOpenBracket..<closingRange.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)

            if tag.hasPrefix("/") {
                index = closingRange.upperBound
                continue
            }

            if tag.hasPrefix("v") {
                let speaker = String(tag.dropFirst())
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                if !speaker.isEmpty {
                    result.append(speaker)
                }
            }

            index = closingRange.upperBound
        }

        return result
    }

    private static func normalizeNewlines(_ value: String) -> String {
        let normalized = value
            .trimmingPrefixBOM()
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")

        if !normalized.hasPrefix("\u{FEFF}") && normalized.contains("\u{FEFF}") {
            return "\u{FEFF}" + normalized
        }

        return normalized
    }
}

private extension String {
    func trimmingPrefixBOM() -> String {
        guard let first = unicodeScalars.first, first == UnicodeScalar(0xFEFF) else { return self }
        return String(dropFirst())
    }
}
