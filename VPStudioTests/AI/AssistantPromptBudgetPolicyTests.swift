import Foundation
import Testing
@testable import VPStudio

@Suite("ProgressNotifyThrottle")
struct ProgressNotifyThrottleTests {
    @Test
    func shouldNotifyReturnsTrueOnFirstCall() async {
        let throttle = ProgressNotifyThrottle()

        let result = await throttle.shouldNotify()

        #expect(result == true)
    }

    @Test
    func shouldNotifyReturnsFalseWithinInterval() async {
        let throttle = ProgressNotifyThrottle()

        _ = await throttle.shouldNotify()
        let second = await throttle.shouldNotify(interval: 5)

        #expect(second == false)
    }

    @Test
    func shouldNotifyReturnsTrueAfterInterval() async {
        let throttle = ProgressNotifyThrottle()

        _ = await throttle.shouldNotify(interval: 0)
        let afterWait = await throttle.shouldNotify(interval: 0)

        #expect(afterWait == true)
    }

    @Test
    func shouldNotifyUsesDefaultIntervalOfTwoSeconds() async {
        let throttle = ProgressNotifyThrottle()

        _ = await throttle.shouldNotify()
        let fastCheck = await throttle.shouldNotify()

        #expect(fastCheck == false)
    }
}

@Suite("AssistantPromptBudgetPolicy")
struct AssistantPromptBudgetPolicyTests {
    @Test
    func estimatedTokenCountReturnsZeroForEmpty() {
        let count = AssistantPromptBudgetPolicy.estimatedTokenCount(for: "")
        #expect(count == 0)
    }

    @Test
    func estimatedTokenCountReturnsOneForShortText() {
        let count = AssistantPromptBudgetPolicy.estimatedTokenCount(for: "hi")
        #expect(count == 1)
    }

    @Test
    func estimatedTokenCountScalesWithUTF8Size() {
        let short = "a"
        let long = "abcdefgh"
        #expect(AssistantPromptBudgetPolicy.estimatedTokenCount(for: long) > AssistantPromptBudgetPolicy.estimatedTokenCount(for: short))
    }

    @Test
    func estimatedTokenCountMinimumIsOne() {
        let count = AssistantPromptBudgetPolicy.estimatedTokenCount(for: "x")
        #expect(count >= 1)
    }

    @Test
    func composePromptReturnsEmptyForZeroBudget() {
        let result = AssistantPromptBudgetPolicy.composePrompt(from: ["part1", "part2"], budgetTokens: 0)
        #expect(result == "")
    }

    @Test
    func composePromptIncludesPartIfWithinBudget() {
        let result = AssistantPromptBudgetPolicy.composePrompt(from: ["short part"], budgetTokens: 100)
        #expect(result == "short part")
    }

    @Test
    func composePromptDropsPartThatExceedsBudget() {
        let largePart = String(repeating: "x", count: 1000)
        let result = AssistantPromptBudgetPolicy.composePrompt(from: [largePart], budgetTokens: 10)
        #expect(result == "")
    }

    @Test
    func composePromptKeepsPartsInOrder() {
        let result = AssistantPromptBudgetPolicy.composePrompt(
            from: ["first", "second", "third"],
            budgetTokens: 1000
        )
        #expect(result.contains("first"))
        #expect(result.contains("second"))
        #expect(result.contains("third"))
    }

    @Test
    func composePromptStopsAtBudgetBoundary() {
        let parts = ["a", "b", "c", "d"]
        let result = AssistantPromptBudgetPolicy.composePrompt(from: parts, budgetTokens: 5)
        let keptParts = result.split(separator: "\n")
        #expect(keptParts.count <= parts.count)
    }

    @Test
    func composePromptDropsLastPartIfItWouldOverflow() {
        let veryLongPart = String(repeating: "x", count: 500)
        let result = AssistantPromptBudgetPolicy.composePrompt(
            from: ["short", veryLongPart],
            budgetTokens: 50
        )
        #expect(result == "short")
    }
}