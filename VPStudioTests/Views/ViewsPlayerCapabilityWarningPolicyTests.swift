import Testing
@testable import VPStudio

@Suite("PlayerCapabilityWarningPolicy Constants")
struct PlayerCapabilityWarningPolicyConstantsTests {
    @Test("Max inline warnings")
    func maxInlineWarnings() {
        #expect(PlayerCapabilityWarningPolicy.maxInlineWarnings == 1)
    }

    @Test("Max inline characters")
    func maxInlineCharacters() {
        #expect(PlayerCapabilityWarningPolicy.maxInlineCharacters == 72)
    }
}

@Suite("PlayerCapabilityWarningPolicy Inline Message")
struct PlayerCapabilityWarningPolicyInlineMessageTests {
    @Test("Empty warnings returns nil")
    func emptyWarnings() {
        #expect(PlayerCapabilityWarningPolicy.inlineMessage(for: []) == nil)
    }

    @Test("Single warning returns first warning")
    func singleWarning() {
        #expect(PlayerCapabilityWarningPolicy.inlineMessage(for: ["Warning text"]) == "Warning text")
    }

    @Test("Multiple warnings returns first warning")
    func multipleWarnings() {
        #expect(PlayerCapabilityWarningPolicy.inlineMessage(for: ["First", "Second", "Third"]) == "First")
    }

    @Test("Long warning is truncated")
    func truncation() {
        let longWarning = String(repeating: "x", count: 200)
        let result = PlayerCapabilityWarningPolicy.inlineMessage(for: [longWarning])
        #expect(result != nil)
        #expect(result!.count < longWarning.count)
        #expect(result!.hasSuffix("…"))
    }

    @Test("Exact max characters is not truncated")
    func exactMaxNotTruncated() {
        let exactWarning = String(repeating: "x", count: 72)
        #expect(PlayerCapabilityWarningPolicy.inlineMessage(for: [exactWarning]) == exactWarning)
    }
}

@Suite("PlayerCapabilityWarningPolicy Overflow Count")
struct PlayerCapabilityWarningPolicyOverflowTests {
    @Test("Empty warnings returns zero")
    func emptyWarnings() {
        #expect(PlayerCapabilityWarningPolicy.overflowCount(for: []) == 0)
    }

    @Test("One warning returns zero")
    func oneWarning() {
        #expect(PlayerCapabilityWarningPolicy.overflowCount(for: ["Single"]) == 0)
    }

    @Test("Two warnings returns one overflow")
    func twoWarnings() {
        #expect(PlayerCapabilityWarningPolicy.overflowCount(for: ["First", "Second"]) == 1)
    }

    @Test("Five warnings returns four overflow")
    func fiveWarnings() {
        #expect(PlayerCapabilityWarningPolicy.overflowCount(for: ["A", "B", "C", "D", "E"]) == 4)
    }
}
