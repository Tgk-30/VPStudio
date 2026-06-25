import Foundation
import Testing
@testable import VPStudio

@Suite("DebridCloudPolicy")
struct DebridCloudPolicyTests {
    @Test
    func premiumSummaryHandlesFreeExpiredAndUnknownStatuses() {
        let now = Date(timeIntervalSince1970: 1_000)

        #expect(DebridCloudPolicy.premiumSummary(isPremium: false, expiry: nil, now: now) == "Free account")
        #expect(DebridCloudPolicy.premiumSummary(isPremium: true, expiry: now, now: now) == "Expired")
        #expect(DebridCloudPolicy.premiumSummary(isPremium: nil, expiry: nil, now: now) == "Status unknown")
    }

    @Test
    func premiumSummaryUsesReadableExpiryWindow() {
        let now = Date(timeIntervalSince1970: 1_767_270_400)
        let laterToday = now.addingTimeInterval(60 * 60)
        let tomorrow = now.addingTimeInterval(24 * 60 * 60)
        let later = now.addingTimeInterval(9 * 24 * 60 * 60)

        #expect(DebridCloudPolicy.premiumSummary(isPremium: true, expiry: laterToday, now: now) == "Premium expires today")
        #expect(DebridCloudPolicy.premiumSummary(isPremium: true, expiry: tomorrow, now: now) == "Premium expires tomorrow")
        #expect(DebridCloudPolicy.premiumSummary(isPremium: true, expiry: later, now: now) == "Premium expires in 9 days")
    }

    @Test
    func accountRowUsesConfigIdentityAndServiceDisplayName() {
        let config = DebridConfig(
            id: "rd-1",
            serviceType: .realDebrid,
            apiTokenRef: "token",
            priority: 3
        )
        let account = DebridAccountInfo(
            username: "brendan",
            email: "b@example.com",
            premiumExpiry: nil,
            isPremium: true
        )

        let row = DebridCloudPolicy.accountRow(config: config, account: account)

        #expect(row.id == "rd-1")
        #expect(row.serviceName == DebridServiceType.realDebrid.displayName)
        #expect(row.username == "brendan")
        #expect(row.email == "b@example.com")
        #expect(row.premiumSummary == "Premium active")
        #expect(row.isPremium == true)
        #expect(row.needsAttention == false)
    }

    @Test
    func accountRowsFlagFreeExpiredAndUnknownStatusesForAttention() {
        let now = Date(timeIntervalSince1970: 1_767_270_400)
        let config = DebridConfig(
            id: "pm-1",
            serviceType: .premiumize,
            apiTokenRef: "token",
            priority: 1
        )

        let free = DebridCloudPolicy.accountRow(
            config: config,
            account: DebridAccountInfo(
                username: "free",
                email: nil,
                premiumExpiry: nil,
                isPremium: false
            ),
            now: now
        )
        let expired = DebridCloudPolicy.accountRow(
            config: config,
            account: DebridAccountInfo(
                username: "expired",
                email: nil,
                premiumExpiry: now,
                isPremium: true
            ),
            now: now
        )
        let unknown = DebridCloudPolicy.accountRow(
            config: config,
            account: DebridAccountInfo(
                username: "unknown",
                email: nil,
                premiumExpiry: nil,
                isPremium: nil
            ),
            now: now
        )
        let expiringToday = DebridCloudPolicy.accountRow(
            config: config,
            account: DebridAccountInfo(
                username: "soon",
                email: nil,
                premiumExpiry: now.addingTimeInterval(60 * 60),
                isPremium: true
            ),
            now: now
        )

        #expect(free.needsAttention)
        #expect(expired.needsAttention)
        #expect(unknown.needsAttention)
        #expect(expiringToday.needsAttention)
        #expect(expiringToday.premiumSummary == "Premium expires today")
    }

    @Test
    func accountRowsKeepFuturePremiumStatusesHealthy() {
        let now = Date(timeIntervalSince1970: 1_767_270_400)
        let config = DebridConfig(
            id: "tb-1",
            serviceType: .torBox,
            apiTokenRef: "token",
            priority: 2
        )

        let tomorrow = DebridCloudPolicy.accountRow(
            config: config,
            account: DebridAccountInfo(
                username: "tomorrow",
                email: nil,
                premiumExpiry: now.addingTimeInterval(24 * 60 * 60),
                isPremium: true
            ),
            now: now
        )
        let future = DebridCloudPolicy.accountRow(
            config: config,
            account: DebridAccountInfo(
                username: "future",
                email: nil,
                premiumExpiry: now.addingTimeInterval(14 * 24 * 60 * 60),
                isPremium: true
            ),
            now: now
        )

        #expect(tomorrow.needsAttention == false)
        #expect(tomorrow.premiumSummary == "Premium expires tomorrow")
        #expect(future.needsAttention == false)
        #expect(future.premiumSummary == "Premium expires in 14 days")
    }
}
