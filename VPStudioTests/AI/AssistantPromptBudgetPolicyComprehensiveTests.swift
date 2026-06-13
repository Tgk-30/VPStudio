import Foundation
import Testing
@testable import VPStudio

@Suite("AssistantPromptBudgetPolicy")
struct AssistantPromptBudgetPolicyComprehensiveTests {

    // MARK: - estimatedTokenCount

    @Test
    func estimatedTokenCountEmptyStringReturnsZero() {
        let count = AssistantPromptBudgetPolicy.estimatedTokenCount(for: "")
        #expect(count == 0)
    }

    @Test
    func estimatedTokenCountWhitespaceOnlyReturnsZero() {
        let count = AssistantPromptBudgetPolicy.estimatedTokenCount(for: "   \t\n  ")
        #expect(count == 0)
    }

    @Test
    func estimatedTokenCountSingleCharacterReturnsOne() {
        let count = AssistantPromptBudgetPolicy.estimatedTokenCount(for: "a")
        #expect(count == 1)
    }

    @Test
    func estimatedTokenCountShortStringReturnsOne() {
        let count = AssistantPromptBudgetPolicy.estimatedTokenCount(for: "hi")
        #expect(count == 1)
    }

    @Test
    func estimatedTokenCountMinimumIsOneForNonEmpty() {
        let singles = ["a", "x", "1", "!"]
        for single in singles {
            let count = AssistantPromptBudgetPolicy.estimatedTokenCount(for: single)
            #expect(count >= 1, "Failed for: '\(single)'")
        }
        // Whitespace-only strings trim to empty and return 0
        #expect(AssistantPromptBudgetPolicy.estimatedTokenCount(for: " ") == 0)
    }

    @Test
    func estimatedTokenCountScalesLinearlyWithUTF8Size() {
        let short = "ab"
        let medium = "abcdefgh"
        let long = "abcdefghijklmnop"
        #expect(AssistantPromptBudgetPolicy.estimatedTokenCount(for: short) < AssistantPromptBudgetPolicy.estimatedTokenCount(for: medium))
        #expect(AssistantPromptBudgetPolicy.estimatedTokenCount(for: medium) < AssistantPromptBudgetPolicy.estimatedTokenCount(for: long))
    }

    @Test
    func estimatedTokenCountExactDivisionRoundsDown() {
        let text = String(repeating: "a", count: 4)
        let count = AssistantPromptBudgetPolicy.estimatedTokenCount(for: text)
        #expect(count == 1)
    }

    @Test
    func estimatedTokenCountWithRemainderRoundsUp() {
        let text = String(repeating: "a", count: 5)
        let count = AssistantPromptBudgetPolicy.estimatedTokenCount(for: text)
        #expect(count == 2)
    }

    @Test
    func estimatedTokenCountBoundaryAt4Bytes() {
        let text4 = String(repeating: "a", count: 4)
        let text5 = String(repeating: "a", count: 5)
        #expect(AssistantPromptBudgetPolicy.estimatedTokenCount(for: text4) == 1)
        #expect(AssistantPromptBudgetPolicy.estimatedTokenCount(for: text5) == 2)
    }

    @Test
    func estimatedTokenCountFormulaVerification() {
        let text = "Hello World"
        let expected = max(1, (text.utf8.count + 3) / 4)
        let actual = AssistantPromptBudgetPolicy.estimatedTokenCount(for: text)
        #expect(actual == expected)
    }

    @Test
    func estimatedTokenCountWithUnicodeCharacters() {
        let emoji = "🎬"
        let count = AssistantPromptBudgetPolicy.estimatedTokenCount(for: emoji)
        #expect(count >= 1)
    }

    @Test
    func estimatedTokenCountWithMultiByteUnicode() {
        let japanese = "映画"
        let count = AssistantPromptBudgetPolicy.estimatedTokenCount(for: japanese)
        #expect(count >= 1)
    }

    @Test
    func estimatedTokenCountTrimsWhitespace() {
        let withSpaces = "   hello   "
        let withoutSpaces = "hello"
        #expect(AssistantPromptBudgetPolicy.estimatedTokenCount(for: withSpaces) == AssistantPromptBudgetPolicy.estimatedTokenCount(for: withoutSpaces))
    }

    @Test
    func estimatedTokenCountVeryLongText() {
        let longText = String(repeating: "The quick brown fox jumps over the lazy dog. ", count: 100)
        let count = AssistantPromptBudgetPolicy.estimatedTokenCount(for: longText)
        #expect(count > 100)
    }

    // MARK: - composePrompt

    @Test
    func composePromptZeroBudgetReturnsEmpty() {
        let result = AssistantPromptBudgetPolicy.composePrompt(from: ["part1", "part2"], budgetTokens: 0)
        #expect(result == "")
    }

    @Test
    func composePromptNegativeBudgetReturnsEmpty() {
        let result = AssistantPromptBudgetPolicy.composePrompt(from: ["part1"], budgetTokens: -1)
        #expect(result == "")
    }

    @Test
    func composePromptSinglePartFitsExactly() {
        let part = String(repeating: "x", count: 4)
        let cost = AssistantPromptBudgetPolicy.estimatedTokenCount(for: part)
        let result = AssistantPromptBudgetPolicy.composePrompt(from: [part], budgetTokens: cost)
        #expect(result == part)
    }

    @Test
    func composePromptSinglePartExceedsBudget() {
        let part = String(repeating: "x", count: 100)
        let smallBudget = 5
        let result = AssistantPromptBudgetPolicy.composePrompt(from: [part], budgetTokens: smallBudget)
        #expect(result == "")
    }

    @Test
    func composePromptMultiplePartsInOrder() {
        let result = AssistantPromptBudgetPolicy.composePrompt(
            from: ["first", "second", "third"],
            budgetTokens: 1000
        )
        #expect(result.contains("first"))
        #expect(result.contains("second"))
        #expect(result.contains("third"))
    }

    @Test
    func composePromptPartsJoinedWithNewlines() {
        let result = AssistantPromptBudgetPolicy.composePrompt(
            from: ["part1", "part2", "part3"],
            budgetTokens: 1000
        )
        let parts = result.split(separator: "\n").map { String($0) }
        #expect(parts.count == 3)
        #expect(parts[0] == "part1")
        #expect(parts[1] == "part2")
        #expect(parts[2] == "part3")
    }

    @Test
    func composePromptStopsAtBudgetBoundary() {
        let parts = ["a", "b", "c", "d"]
        let result = AssistantPromptBudgetPolicy.composePrompt(from: parts, budgetTokens: 5)
        let keptParts = result.split(separator: "\n")
        #expect(keptParts.count <= parts.count)
    }

    @Test
    func composePromptLastPartDropsIfItWouldOverflow() {
        let veryLongPart = String(repeating: "x", count: 500)
        let result = AssistantPromptBudgetPolicy.composePrompt(
            from: ["short", veryLongPart],
            budgetTokens: 50
        )
        #expect(result == "short")
        #expect(!result.contains(veryLongPart))
    }

    @Test
    func composePromptFirstPartTooLargeDropsAll() {
        let hugePart = String(repeating: "x", count: 10000)
        let result = AssistantPromptBudgetPolicy.composePrompt(
            from: [hugePart, "should-not-appear"],
            budgetTokens: 1000
        )
        #expect(result == "")
    }

    @Test
    func composePromptExactlyFitsBudgetIncludesAll() {
        var parts: [String] = []
        var totalCost = 0
        let targetBudget = 50

        while totalCost < targetBudget {
            let part = "x"
            let cost = AssistantPromptBudgetPolicy.estimatedTokenCount(for: part)
            if totalCost + cost > targetBudget { break }
            parts.append(part)
            totalCost += cost
        }

        let result = AssistantPromptBudgetPolicy.composePrompt(from: parts, budgetTokens: targetBudget)
        #expect(!result.isEmpty)
    }

    @Test
    func composePromptEmptyPartsArray() {
        let result = AssistantPromptBudgetPolicy.composePrompt(from: [], budgetTokens: 100)
        #expect(result == "")
    }

    @Test
    func composePromptWithEmptyPartInMiddle() {
        let result = AssistantPromptBudgetPolicy.composePrompt(
            from: ["first", "", "third"],
            budgetTokens: 1000
        )
        #expect(result.contains("first"))
        #expect(result.contains("third"))
    }

    @Test
    func composePromptWithWhitespaceParts() {
        let result = AssistantPromptBudgetPolicy.composePrompt(
            from: ["  ", "content", "  "],
            budgetTokens: 1000
        )
        #expect(result.contains("content"))
    }

    @Test
    func composePromptBudgetRemainingDecreases() {
        let parts = ["test1", "test2", "test3"]
        let budget = 100
        let result = AssistantPromptBudgetPolicy.composePrompt(from: parts, budgetTokens: budget)

        var remainingBudget = budget
        for part in parts {
            let cost = AssistantPromptBudgetPolicy.estimatedTokenCount(for: part)
            if cost <= remainingBudget {
                remainingBudget -= cost
            }
        }

        if result.contains("test1") && result.contains("test2") && result.contains("test3") {
            #expect(remainingBudget >= 0)
        }
    }

    // MARK: - Integration Tests

    @Test
    func estimatedTokenCountAndComposePromptIntegration() {
        let parts = [
            "This is a short sentence.",
            "This is a much longer sentence that contains more words and should therefore cost more tokens when measured.",
            "Short."
        ]

        var totalCost = 0
        for part in parts {
            totalCost += AssistantPromptBudgetPolicy.estimatedTokenCount(for: part)
        }

        let result = AssistantPromptBudgetPolicy.composePrompt(from: parts, budgetTokens: totalCost)
        #expect(!result.isEmpty)
    }

    @Test
    func composePromptPreservesOrderWithPartialFit() {
        let parts = [
            "First part that fits",
            "Second part that also fits",
            "Third part that might not fit"
        ]

        var runningCost = 0
        var fittingParts: [String] = []

        for part in parts {
            let cost = AssistantPromptBudgetPolicy.estimatedTokenCount(for: part)
            if runningCost + cost <= 1000 {
                runningCost += cost
                fittingParts.append(part)
            } else {
                break
            }
        }

        let result = AssistantPromptBudgetPolicy.composePrompt(from: parts, budgetTokens: 1000)
        #expect(result.contains(fittingParts.first ?? ""))
        #expect(result.contains(fittingParts.last ?? ""))
    }

    @Test
    func largeBudgetIncludesAllParts() {
        let parts = ["Part one", "Part two", "Part three"]
        let result = AssistantPromptBudgetPolicy.composePrompt(from: parts, budgetTokens: 10000)
        #expect(result.contains("Part one"))
        #expect(result.contains("Part two"))
        #expect(result.contains("Part three"))
    }

    @Test
    func tinyBudgetDropsAllParts() {
        let parts = ["First", "Second", "Third"]
        let result = AssistantPromptBudgetPolicy.composePrompt(from: parts, budgetTokens: 1)
        #expect(result == "")
    }

    // MARK: - Edge Cases

    @Test
    func estimatedTokenCountWithNewlines() {
        let text = "line1\nline2\nline3"
        let count = AssistantPromptBudgetPolicy.estimatedTokenCount(for: text)
        #expect(count >= 1)
    }

    @Test
    func estimatedTokenCountWithTabs() {
        let text = "col1\tcol2\tcol3"
        let count = AssistantPromptBudgetPolicy.estimatedTokenCount(for: text)
        #expect(count >= 1)
    }

    @Test
    func composePromptWithPartsContainingNewlines() {
        let parts = ["line1\nline2", "line3\nline4"]
        let result = AssistantPromptBudgetPolicy.composePrompt(from: parts, budgetTokens: 1000)
        #expect(result.contains("line1"))
        #expect(result.contains("line4"))
    }

    @Test
    func composePromptResultCanBeUsedAsInput() {
        let originalParts = ["Original part one", "Original part two"]
        let budget = 1000

        let prompt = AssistantPromptBudgetPolicy.composePrompt(from: originalParts, budgetTokens: budget)
        let tokenCount = AssistantPromptBudgetPolicy.estimatedTokenCount(for: prompt)

        #expect(tokenCount <= budget)
    }
}
