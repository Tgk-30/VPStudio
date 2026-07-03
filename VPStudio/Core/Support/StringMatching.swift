import Foundation

// MARK: - Media container extensions

extension String {
    /// Video/container file extensions that indexer/addon results sometimes carry
    /// as a trailing filename suffix. Kept lowercase for case-insensitive matching.
    static let knownMediaContainerExtensions: Set<String> = [
        "ts", "mkv", "mp4", "m4v", "avi", "mov", "wmv", "flv", "webm",
        "mpg", "mpeg", "m2ts", "mts", "vob", "ogm", "ogv", "divx", "mk3d", "3gp"
    ]

    /// Returns the receiver with a single trailing recognized media-container
    /// extension removed (e.g. `"episode.title.ts"` → `"episode.title"`).
    ///
    /// This exists so source/quality parsing does not misread a container
    /// extension as a release token — most importantly, so a legitimate `.ts`
    /// (MPEG transport stream) filename is not classified as a `TS`/TELESYNC
    /// camera source and silently hidden by the default "No CAM" filter.
    func strippingTrailingMediaContainerExtension() -> String {
        guard let dotIndex = lastIndex(of: ".") else { return self }
        let ext = self[index(after: dotIndex)...].lowercased()
        guard String.knownMediaContainerExtensions.contains(ext) else { return self }
        return String(self[..<dotIndex])
    }
}

// MARK: - Standalone token matching

extension String {
    /// Returns `true` if `token` appears in the receiver as a word-boundary-delimited token.
    ///
    /// A token is "standalone" when it is not embedded in another alphabetic word.
    /// Numeric suffixes and prefixes are accepted when the number itself is bounded,
    /// so `"sbs2"` and `"2sbs"` match while `"movie2sbs"` does not.
    ///
    /// - Parameter token: The token to search for (must already be lowercased if case-insensitivity
    ///   is required, since the receiver is searched case-insensitively regardless).
    func containsStandaloneToken(_ token: String) -> Bool {
        guard !token.isEmpty else { return false }

        let tokenIsNumeric = token.allSatisfy(\.isNumber)
        var searchStart = startIndex
        while let range = range(of: token, options: [.caseInsensitive], range: searchStart..<endIndex) {
            if isStandaloneTokenRange(range, token: token, tokenIsNumeric: tokenIsNumeric) {
                return true
            }
            searchStart = index(after: range.lowerBound)
        }

        return false
    }

    private func isStandaloneTokenRange(
        _ range: Range<String.Index>,
        token: String,
        tokenIsNumeric: Bool
    ) -> Bool {
        isStandaloneTokenLeftBoundary(at: range.lowerBound, token: token, tokenIsNumeric: tokenIsNumeric)
            && isStandaloneTokenRightBoundary(at: range.upperBound, tokenIsNumeric: tokenIsNumeric)
    }

    private func isStandaloneTokenLeftBoundary(
        at index: String.Index,
        token: String,
        tokenIsNumeric: Bool
    ) -> Bool {
        guard index > startIndex else { return true }
        let previousIndex = self.index(before: index)
        let previous = self[previousIndex]

        if tokenIsNumeric {
            if previous.isNumber { return false }
            return String(previous).lowercased() != "p"
        }

        if previous.isLetter { return false }
        guard previous.isNumber else { return true }

        let digitRunStart = startOfNumberRun(endingAt: previousIndex)
        guard digitRunStart != startIndex else { return true }

        let beforeDigitsIndex = self.index(before: digitRunStart)
        let beforeDigits = self[beforeDigitsIndex]
        if !beforeDigits.isLetter && !beforeDigits.isNumber { return true }

        return tokenImmediatelyPrecedesNumberRun(startingAt: digitRunStart, token: token)
    }

    private func isStandaloneTokenRightBoundary(
        at index: String.Index,
        tokenIsNumeric: Bool
    ) -> Bool {
        guard index < endIndex else { return true }
        let next = self[index]

        if tokenIsNumeric {
            return !next.isLetter && !next.isNumber
        }

        if next.isLetter { return false }
        guard next.isNumber else { return true }

        let afterNextIndex = self.index(after: index)
        guard afterNextIndex < endIndex else { return true }

        let afterNext = self[afterNextIndex]
        return !afterNext.isLetter && !afterNext.isNumber
    }

    private func startOfNumberRun(endingAt lastNumberIndex: String.Index) -> String.Index {
        var current = lastNumberIndex
        while current > startIndex {
            let previous = self.index(before: current)
            guard self[previous].isNumber else { break }
            current = previous
        }
        return current
    }

    private func tokenImmediatelyPrecedesNumberRun(startingAt digitRunStart: String.Index, token: String) -> Bool {
        var tokenStart = digitRunStart
        for _ in token {
            guard tokenStart > startIndex else { return false }
            tokenStart = index(before: tokenStart)
        }

        let previousToken = String(self[tokenStart..<digitRunStart])
        guard previousToken.caseInsensitiveCompare(token) == .orderedSame else {
            return false
        }

        guard tokenStart > startIndex else { return true }
        let beforeToken = self[index(before: tokenStart)]
        return !beforeToken.isLetter && !beforeToken.isNumber
    }
}
