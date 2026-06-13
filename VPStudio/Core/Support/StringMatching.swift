import Foundation

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
            if isStandaloneTokenRange(range, tokenIsNumeric: tokenIsNumeric) {
                return true
            }
            searchStart = index(after: range.lowerBound)
        }

        return false
    }

    private func isStandaloneTokenRange(
        _ range: Range<String.Index>,
        tokenIsNumeric: Bool
    ) -> Bool {
        isStandaloneTokenLeftBoundary(at: range.lowerBound, tokenIsNumeric: tokenIsNumeric)
            && isStandaloneTokenRightBoundary(at: range.upperBound, tokenIsNumeric: tokenIsNumeric)
    }

    private func isStandaloneTokenLeftBoundary(
        at index: String.Index,
        tokenIsNumeric: Bool
    ) -> Bool {
        guard index > startIndex else { return true }
        let previousIndex = self.index(before: index)
        let previous = self[previousIndex]

        if previous.isLetter { return false }
        guard previous.isNumber else { return true }
        if tokenIsNumeric { return false }
        guard previousIndex > startIndex else { return true }

        let beforePrevious = self[self.index(before: previousIndex)]
        return !beforePrevious.isLetter && !beforePrevious.isNumber
    }

    private func isStandaloneTokenRightBoundary(
        at index: String.Index,
        tokenIsNumeric: Bool
    ) -> Bool {
        guard index < endIndex else { return true }
        let next = self[index]

        if next.isLetter { return false }
        guard next.isNumber else { return true }
        if tokenIsNumeric { return false }

        let afterNextIndex = self.index(after: index)
        guard afterNextIndex < endIndex else { return true }

        let afterNext = self[afterNextIndex]
        return !afterNext.isLetter && !afterNext.isNumber
    }
}
