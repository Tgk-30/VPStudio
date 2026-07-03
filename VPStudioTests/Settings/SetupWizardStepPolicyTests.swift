import Foundation
import Testing
@testable import VPStudio

@Suite("Setup Wizard Step Policy")
struct SetupWizardStepPolicyTests {
    @Test func emptyTokenSkipsRegardlessOfFormatResult() {
        #expect(
            SetupWizardStepPolicy.debridStepOutcome(formatResult: .empty, tokenIsEmpty: true) == .skip
        )
        // Even if a (stale) format result says plausible, an empty token skips.
        #expect(
            SetupWizardStepPolicy.debridStepOutcome(formatResult: .plausible, tokenIsEmpty: true) == .skip
        )
    }

    @Test func emptyFormatResultSkips() {
        #expect(
            SetupWizardStepPolicy.debridStepOutcome(formatResult: .empty, tokenIsEmpty: false) == .skip
        )
    }

    @Test func plausibleFormatResultValidates() {
        #expect(
            SetupWizardStepPolicy.debridStepOutcome(formatResult: .plausible, tokenIsEmpty: false) == .validate
        )
    }

    @Test func malformedFormatResultBlocksWithMessage() {
        let reason = "This key looks too short."
        let outcome = SetupWizardStepPolicy.debridStepOutcome(
            formatResult: .malformed(reason: reason),
            tokenIsEmpty: false
        )
        #expect(outcome == .blockFormat(message: reason))
    }

    @Test func endToEndPlausibleKeyRoutesToValidate() {
        let key = "ABCDEFGHIJKLMNOP1234"
        let formatResult = DebridKeyValidationPolicy.formatCheck(for: .realDebrid, key: key)
        let outcome = SetupWizardStepPolicy.debridStepOutcome(
            formatResult: formatResult,
            tokenIsEmpty: DebridKeyValidationPolicy.normalize(key).isEmpty
        )
        #expect(outcome == .validate)
    }

    @Test func endToEndMalformedKeyRoutesToBlock() {
        let key = "abc" // too short
        let formatResult = DebridKeyValidationPolicy.formatCheck(for: .realDebrid, key: key)
        let outcome = SetupWizardStepPolicy.debridStepOutcome(
            formatResult: formatResult,
            tokenIsEmpty: DebridKeyValidationPolicy.normalize(key).isEmpty
        )
        guard case .blockFormat = outcome else {
            Issue.record("Expected .blockFormat for a too-short key, got \(outcome)")
            return
        }
    }
}

@Suite("Setup Wizard Indexer Seeding Policy")
struct SetupWizardIndexerSeedingPolicyTests {
    @Test func emptyListSeedsExactlyDefaultConfigs() throws {
        let plan = SetupWizardIndexerSeedingPolicy.seedPlan(existingConfigs: [])
        let seeded = try #require(plan)
        let defaults = IndexerDefaultRanking.defaultConfigs()

        #expect(seeded == defaults)
        // Sanity: the seed must contain every ranked default, in priority order.
        #expect(seeded.map(\.id) == defaults.map(\.id))
        #expect(seeded.map(\.priority) == Array(0..<defaults.count))
    }

    @Test func nonEmptyListIsNoOp() {
        let existing = [Fixtures.indexerConfig(id: "custom", name: "Custom")]
        #expect(SetupWizardIndexerSeedingPolicy.seedPlan(existingConfigs: existing) == nil)
    }

    @Test func completionSummaryListsActiveProvidersInPriorityOrder() throws {
        let configs = try #require(SetupWizardIndexerSeedingPolicy.seedPlan(existingConfigs: []))
        let summary = SetupWizardIndexerSeedingPolicy.completionSummary(for: configs)

        let expectedNames = configs
            .filter(\.isActive)
            .sorted { $0.priority < $1.priority }
            .map(\.name)

        #expect(summary == "Search providers ready: \(expectedNames.joined(separator: ", "))")
        #expect(summary?.hasPrefix("Search providers ready: ") == true)
    }

    @Test func completionSummaryIsNilWhenNoActiveProviders() {
        let inactive = [
            Fixtures.indexerConfig(id: "a", name: "A"),
            Fixtures.indexerConfig(id: "b", name: "B"),
        ].map { config -> IndexerConfig in
            var copy = config
            copy.isActive = false
            return copy
        }
        #expect(SetupWizardIndexerSeedingPolicy.completionSummary(for: inactive) == nil)
        #expect(SetupWizardIndexerSeedingPolicy.completionSummary(for: []) == nil)
    }
}
