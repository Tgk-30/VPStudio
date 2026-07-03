import Foundation

enum DebridCloudPolicy {
    struct AccountRow: Identifiable, Equatable {
        let id: String
        let serviceName: String
        let username: String
        let email: String?
        let premiumSummary: String
        let isPremium: Bool?
        let needsAttention: Bool
    }

    private enum PremiumStatus: Equatable {
        case active
        case expiringToday
        case expiringTomorrow
        case expiringInDays(Int)
        case free
        case expired
        case unknown

        var summary: String {
            switch self {
            case .active:
                return "Premium active"
            case .expiringToday:
                return "Premium expires today"
            case .expiringTomorrow:
                return "Premium expires tomorrow"
            case .expiringInDays(let days):
                return "Premium expires in \(days) days"
            case .free:
                return "Free account"
            case .expired:
                return "Expired"
            case .unknown:
                return "Status unknown"
            }
        }

        var needsAttention: Bool {
            switch self {
            case .active, .expiringTomorrow, .expiringInDays(_):
                return false
            case .expiringToday, .free, .expired, .unknown:
                return true
            }
        }
    }

    static func premiumSummary(
        isPremium: Bool?,
        expiry: Date?,
        now: Date = Date()
    ) -> String {
        premiumStatus(isPremium: isPremium, expiry: expiry, now: now).summary
    }

    private static func premiumStatus(
        isPremium: Bool?,
        expiry: Date?,
        now: Date = Date()
    ) -> PremiumStatus {
        if isPremium == false {
            return .free
        }

        guard let expiry else {
            return isPremium == true ? .active : .unknown
        }

        if expiry <= now {
            return .expired
        }

        let calendar = Calendar.current
        if calendar.isDate(expiry, inSameDayAs: now) {
            return .expiringToday
        }

        let days = calendar.dateComponents([.day], from: now, to: expiry).day!
        if days <= 1 {
            return .expiringTomorrow
        }
        return .expiringInDays(days)
    }

    static func accountRow(
        config: DebridConfig,
        account: DebridAccountInfo,
        now: Date = Date()
    ) -> AccountRow {
        let status = premiumStatus(
            isPremium: account.isPremium,
            expiry: account.premiumExpiry,
            now: now
        )

        return AccountRow(
            id: config.id,
            serviceName: config.serviceType.displayName,
            username: account.username,
            email: account.email,
            premiumSummary: status.summary,
            isPremium: account.isPremium,
            needsAttention: status.needsAttention
        )
    }
}
