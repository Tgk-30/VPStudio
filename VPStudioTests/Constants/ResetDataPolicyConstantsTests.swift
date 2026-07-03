import Foundation
import Testing
@testable import VPStudio

@Suite("ResetDataPolicy Constants Tests")
struct ResetDataPolicyConstantsTests {

    @Test("requiredConfirmationPhrase is 'RESET'")
    func requiredConfirmationPhrase() {
        #expect(ResetDataPolicy.requiredConfirmationPhrase == "RESET")
    }

    @Test("resetButtonTitle is non-empty")
    func resetButtonTitleNonEmpty() {
        #expect(!ResetDataPolicy.resetButtonTitle.isEmpty)
    }

    @Test("progressAccessibilityLabel is non-empty")
    func progressAccessibilityLabelNonEmpty() {
        #expect(!ResetDataPolicy.progressAccessibilityLabel.isEmpty)
    }

    @Test("deletionItems contains expected items")
    func deletionItemsContainsExpected() {
        #expect(ResetDataPolicy.deletionItems.count == 5)
        let titles = ResetDataPolicy.deletionItems.map { $0.title }
        #expect(titles.contains("API Keys & Credentials"))
        #expect(titles.contains("Watch History & Library"))
        #expect(titles.contains("Downloads"))
        #expect(titles.contains("Environment Assets"))
        #expect(titles.contains("All Settings"))
    }

    @Test("deletionItems have non-empty icons and titles")
    func deletionItemsNonEmpty() {
        for item in ResetDataPolicy.deletionItems {
            #expect(!item.icon.isEmpty)
            #expect(!item.title.isEmpty)
        }
    }

    @Test("DeletionItem conforms to Equatable")
    func deletionItemEquatable() {
        let item1 = ResetDataPolicy.DeletionItem(icon: "key.fill", title: "Test")
        let item2 = ResetDataPolicy.DeletionItem(icon: "key.fill", title: "Test")
        #expect(item1 == item2)
    }
}

@Suite("ResetDataPolicy Normalization Tests")
struct ResetDataPolicyNormalizationTests {

    @Test("normalizedConfirmationText trims whitespace")
    func normalizationTrimsWhitespace() {
        #expect(ResetDataPolicy.normalizedConfirmationText("  RESET  ") == "RESET")
        #expect(ResetDataPolicy.normalizedConfirmationText("\tRESET\n") == "RESET")
    }

    @Test("normalizedConfirmationText returns empty string for only whitespace")
    func normalizationEmptyForWhitespace() {
        #expect(ResetDataPolicy.normalizedConfirmationText("   ").isEmpty)
    }

    @Test("canExecuteReset returns true for correct phrase")
    func canExecuteResetTrue() {
        #expect(ResetDataPolicy.canExecuteReset(confirmationText: "RESET") == true)
        #expect(ResetDataPolicy.canExecuteReset(confirmationText: "reset") == true)
        #expect(ResetDataPolicy.canExecuteReset(confirmationText: "  reset  ") == true)
    }

    @Test("canExecuteReset returns false for incorrect phrase")
    func canExecuteResetFalse() {
        #expect(ResetDataPolicy.canExecuteReset(confirmationText: "DELETE") == false)
        #expect(ResetDataPolicy.canExecuteReset(confirmationText: "") == false)
        #expect(ResetDataPolicy.canExecuteReset(confirmationText: "RESET!") == false)
    }

    @Test("canExecuteReset returns false when isResetting is true")
    func canExecuteResetFalseWhenResetting() {
        #expect(ResetDataPolicy.canExecuteReset(confirmationText: "RESET", isResetting: true) == false)
    }
}

@Suite("ResetDataStep Enum Tests")
struct ResetDataStepEnumTests {

    @Test("ResetDataStep has expected cases with correct raw values")
    func resetDataStepCases() {
        #expect(ResetDataStep.warning.rawValue == 0)
        #expect(ResetDataStep.secondConfirmation.rawValue == 1)
        #expect(ResetDataStep.finalConfirmation.rawValue == 2)
    }

    @Test("ResetDataStep has exactly 3 cases")
    func resetDataStepCaseCount() {
        #expect(ResetDataStep.allCases.count == 3)
    }
}