import Testing
import Foundation
@testable import VPStudio

@Suite("AIUsageRecord Codable Round-Trip")
struct AIUsageRecordCodableTests {
    @Test("AIUsageRecord encodes and decodes correctly")
    func aiUsageRecordCodableRoundTrip() throws {
        let original = AIUsageRecord(
            id: "usage-123",
            provider: .openAI,
            model: "gpt-4",
            inputTokens: 1000,
            outputTokens: 500,
            estimatedCostUSD: 0.025,
            requestType: .recommendation,
            createdAt: Date(timeIntervalSince1970: 123456789)
        )

        let encoded = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(AIUsageRecord.self, from: encoded)

        #expect(decoded.id == original.id)
        #expect(decoded.provider == original.provider)
        #expect(decoded.model == original.model)
        #expect(decoded.inputTokens == original.inputTokens)
        #expect(decoded.outputTokens == original.outputTokens)
        #expect(decoded.estimatedCostUSD == original.estimatedCostUSD)
        #expect(decoded.requestType == original.requestType)
        #expect(decoded.createdAt == original.createdAt)
    }

    @Test("AIUsageRecord with all request types encodes and decodes correctly")
    func aiUsageRecordAllRequestTypes() throws {
        for requestType in AIRequestType.allCases {
            let record = AIUsageRecord(
                id: "usage-\(requestType.rawValue)",
                provider: .anthropic,
                model: "claude-3",
                inputTokens: 100,
                outputTokens: 50,
                estimatedCostUSD: 0.01,
                requestType: requestType
            )

            let encoded = try JSONEncoder().encode(record)
            let decoded = try JSONDecoder().decode(AIUsageRecord.self, from: encoded)

            #expect(decoded.requestType == requestType.rawValue)
            #expect(decoded.requestTypeKind == requestType)
        }
    }

    @Test("AIUsageRecord providerKind parsing works correctly")
    func aiUsageRecordProviderKindParsing() throws {
        let record = AIUsageRecord(
            provider: .gemini,
            model: "gemini-1.5",
            inputTokens: 200,
            outputTokens: 100,
            estimatedCostUSD: 0.005,
            requestType: .ask
        )

        let encoded = try JSONEncoder().encode(record)
        let decoded = try JSONDecoder().decode(AIUsageRecord.self, from: encoded)

        #expect(decoded.providerKind == .gemini)
    }

    @Test("AIUsageRecord with zero cost encodes and decodes correctly")
    func aiUsageRecordZeroCostCodableRoundTrip() throws {
        let original = AIUsageRecord(
            provider: .local,
            model: "local-model",
            inputTokens: 0,
            outputTokens: 0,
            estimatedCostUSD: 0.0,
            requestType: .ask
        )

        let encoded = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(AIUsageRecord.self, from: encoded)

        #expect(decoded.estimatedCostUSD == 0.0)
        #expect(decoded.providerKind == .local)
    }
}

@Suite("AIRequestType Codable Round-Trip")
struct AIRequestTypeCodableTests {
    @Test("AIRequestType all cases encode and decode correctly")
    func aiRequestTypeAllCasesCodableRoundTrip() throws {
        for requestType in AIRequestType.allCases {
            let encoded = try JSONEncoder().encode(requestType)
            let decoded = try JSONDecoder().decode(AIRequestType.self, from: encoded)
            #expect(decoded == requestType)
        }
    }
}
