import Foundation
import Testing
@testable import VPStudio

@Suite("Debrid Manager Fallback Policy Coverage")
struct DebridManagerFallbackPolicyCoverageTests {
    @Test
    func cacheFallbackPrefersFirstSuccessfulServiceAndMapsFailureToUnknown() async throws {
        let manager = try makeManager()

        let noFailure = await manager.cacheFallbackService(
            firstSuccessfulService: .premiumize,
            orderedServices: [.realDebrid, .premiumize],
            firstFailure: nil
        )
        #expect(noFailure.service == .premiumize)
        #expect(noFailure.status == .notCached)

        let withFailure = await manager.cacheFallbackService(
            firstSuccessfulService: .premiumize,
            orderedServices: [.realDebrid, .premiumize],
            firstFailure: DebridError.networkError("cache failed")
        )
        #expect(withFailure.service == .premiumize)
        #expect(withFailure.status == .unknown)
    }

    @Test
    func cacheFallbackUsesFirstOrderedServiceWhenNoServiceSucceeded() async throws {
        let manager = try makeManager()

        let fallback = await manager.cacheFallbackService(
            firstSuccessfulService: nil,
            orderedServices: [.allDebrid, .realDebrid],
            firstFailure: nil
        )

        #expect(fallback.service == .allDebrid)
        #expect(fallback.status == .notCached)
    }

    private func makeManager() throws -> DebridManager {
        let database = try DatabaseManager(inMemoryNamed: "debrid-fallback-\(UUID().uuidString)")
        return DebridManager(database: database, secretStore: TestSecretStore())
    }
}
