import Foundation
import Testing
@testable import VPStudio

// MARK: - AIUsageRecord

@Suite("AIUsageRecord")
struct AIUsageRecordValueTests {

    @Test func initStoresProviderAsRawValue() {
        let record = AIUsageRecord(
            provider: .anthropic,
            model: "claude-3",
            inputTokens: 100,
            outputTokens: 50,
            estimatedCostUSD: 0.01,
            requestType: .recommendation
        )
        #expect(record.provider == "anthropic")
        #expect(record.requestType == "recommendation")
    }

    @Test func providerKindParsesValidRawValue() {
        let record = AIUsageRecord(
            provider: .gemini,
            model: "gemini-1.5",
            inputTokens: 10,
            outputTokens: 5,
            estimatedCostUSD: 0.001,
            requestType: .ask
        )
        #expect(record.providerKind == .gemini)
    }

    @Test func providerKindReturnsNilForInvalid() {
        var record = AIUsageRecord(
            provider: .openAI,
            model: "gpt-4",
            inputTokens: 1,
            outputTokens: 1,
            estimatedCostUSD: 0,
            requestType: .compare
        )
        record.provider = "invalid_provider"
        #expect(record.providerKind == nil)
    }

    @Test func requestTypeKindParsesValidRawValue() {
        let record = AIUsageRecord(
            provider: .openAI,
            model: "gpt-4",
            inputTokens: 1,
            outputTokens: 1,
            estimatedCostUSD: 0,
            requestType: .ask
        )
        #expect(record.requestTypeKind == .ask)
    }

    @Test func requestTypeKindReturnsNilForInvalid() {
        var record = AIUsageRecord(
            provider: .openAI,
            model: "gpt-4",
            inputTokens: 1,
            outputTokens: 1,
            estimatedCostUSD: 0,
            requestType: .compare
        )
        record.requestType = "invalid"
        #expect(record.requestTypeKind == nil)
    }

    @Test func defaultCreatedAtIsNearNow() {
        let before = Date()
        let record = AIUsageRecord(
            provider: .openAI,
            model: "gpt-4",
            inputTokens: 1,
            outputTokens: 1,
            estimatedCostUSD: 0,
            requestType: .ask
        )
        let after = Date()
        #expect(record.createdAt >= before)
        #expect(record.createdAt <= after)
    }

    @Test func customIDIsPreserved() {
        let record = AIUsageRecord(
            id: "custom-id",
            provider: .openAI,
            model: "gpt-4",
            inputTokens: 1,
            outputTokens: 1,
            estimatedCostUSD: 0,
            requestType: .ask
        )
        #expect(record.id == "custom-id")
    }
}

// MARK: - ProviderUsage

@Suite("ProviderUsage")
struct AIProviderUsageValueTests {

    @Test func equality() {
        let a = ProviderUsage(inputTokens: 100, outputTokens: 50, costUSD: 0.01, requestCount: 1)
        let b = ProviderUsage(inputTokens: 100, outputTokens: 50, costUSD: 0.01, requestCount: 1)
        #expect(a == b)
    }

    @Test func inequality() {
        let a = ProviderUsage(inputTokens: 100, outputTokens: 50, costUSD: 0.01, requestCount: 1)
        let b = ProviderUsage(inputTokens: 200, outputTokens: 50, costUSD: 0.01, requestCount: 1)
        #expect(a != b)
    }
}

// MARK: - AIUsageSummary

@Suite("AIUsageSummary")
struct AIUsageSummaryValueTests {

    @Test func emptySummary() {
        let empty = AIUsageSummary.empty
        #expect(empty.totalInputTokens == 0)
        #expect(empty.totalOutputTokens == 0)
        #expect(empty.totalCostUSD == 0)
        #expect(empty.byProvider.isEmpty)
        #expect(empty.requestCount == 0)
    }

    @Test func equality() {
        let a = AIUsageSummary(
            totalInputTokens: 100,
            totalOutputTokens: 50,
            totalCostUSD: 0.01,
            byProvider: [.openAI: ProviderUsage(inputTokens: 100, outputTokens: 50, costUSD: 0.01, requestCount: 1)],
            requestCount: 1
        )
        let b = AIUsageSummary(
            totalInputTokens: 100,
            totalOutputTokens: 50,
            totalCostUSD: 0.01,
            byProvider: [.openAI: ProviderUsage(inputTokens: 100, outputTokens: 50, costUSD: 0.01, requestCount: 1)],
            requestCount: 1
        )
        #expect(a == b)
    }
}

@Suite("AIUsageRecord Database Round-Trip")
struct AIUsageRecordDatabaseRoundTripTests {
    private func makeTempDatabase() async throws -> (DatabaseManager, URL) {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        let database = try DatabaseManager(inMemoryNamed: "ai-usage-test-\(UUID().uuidString)")
        try await database.migrate()
        return (database, tempDir)
    }

    @Test func roundTripsThroughDatabaseManager() async throws {
        let (database, tempDir) = try await makeTempDatabase()
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let record = AIUsageRecord(
            id: "usage-1",
            provider: .openAI,
            model: "gpt-4",
            inputTokens: 100,
            outputTokens: 50,
            estimatedCostUSD: 0.01,
            requestType: .recommendation
        )
        try await database.saveAIUsageRecord(record)
        let fetched = try await database.fetchAIUsageRecords()

        #expect(fetched.count == 1)
        #expect(fetched.first?.id == record.id)
        #expect(fetched.first?.provider == record.provider)
        #expect(fetched.first?.model == record.model)
        #expect(fetched.first?.inputTokens == record.inputTokens)
    }

    @Test
    func aiUsageRecordWithAllFieldsRoundTripsCorrectly() async throws {
        let (database, tempDir) = try await makeTempDatabase()
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let record = AIUsageRecord(
            id: "full-usage",
            provider: .anthropic,
            model: "claude-3",
            inputTokens: 500,
            outputTokens: 200,
            estimatedCostUSD: 0.05,
            requestType: .ask,
            createdAt: Date(timeIntervalSince1970: 123456789)
        )
        try await database.saveAIUsageRecord(record)
        let fetched = try await database.fetchAIUsageRecords()

        #expect(fetched.count == 1)
        #expect(fetched.first?.providerKind == .anthropic)
        #expect(fetched.first?.model == "claude-3")
        #expect(fetched.first?.inputTokens == 500)
        #expect(fetched.first?.outputTokens == 200)
        #expect(fetched.first?.requestTypeKind == .ask)
    }

    @Test
    func multipleAIUsageRecordsRoundTripCorrectly() async throws {
        let (database, tempDir) = try await makeTempDatabase()
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let records = [
            AIUsageRecord(provider: .openAI, model: "gpt-4", inputTokens: 100, outputTokens: 50, estimatedCostUSD: 0.01, requestType: .recommendation),
            AIUsageRecord(provider: .anthropic, model: "claude-3", inputTokens: 200, outputTokens: 100, estimatedCostUSD: 0.02, requestType: .ask),
            AIUsageRecord(provider: .gemini, model: "gemini-1.5", inputTokens: 300, outputTokens: 150, estimatedCostUSD: 0.03, requestType: .compare)
        ]

        for record in records {
            try await database.saveAIUsageRecord(record)
        }

        let fetched = try await database.fetchAIUsageRecords()
        #expect(fetched.count == 3)
    }

    @Test
    func aiUsageRecordFetchByDateLimitWorks() async throws {
        let (database, tempDir) = try await makeTempDatabase()
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let records = [
            AIUsageRecord(provider: .openAI, model: "gpt-4", inputTokens: 100, outputTokens: 50, estimatedCostUSD: 0.01, requestType: .recommendation),
            AIUsageRecord(provider: .openAI, model: "gpt-4", inputTokens: 200, outputTokens: 100, estimatedCostUSD: 0.02, requestType: .ask)
        ]

        for record in records {
            try await database.saveAIUsageRecord(record)
        }

        let fetched = try await database.fetchAIUsageRecords(limit: 1)
        #expect(fetched.count == 1)
    }
}
