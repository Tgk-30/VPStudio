import Foundation
import Security
import os

protocol SecretStore: Sendable {
    func setSecret(_ secret: String, for key: String) async throws
    func getSecret(for key: String) async throws -> String?
    func deleteSecret(for key: String) async throws
    func deleteAllSecrets() async throws
}

enum SecretStoreError: LocalizedError, Equatable {
    case unexpectedStatus(OSStatus, operation: String)
    case invalidSecretData

    var errorDescription: String? {
        switch self {
        case .unexpectedStatus(let status, let operation):
            return "Keychain \(operation) failed with status \(status)"
        case .invalidSecretData:
            return "Stored secret data is invalid"
        }
    }

    var recoverySuggestion: String? {
        switch self {
        case .unexpectedStatus(let status, let operation):
            if status == errSecAuthFailed {
                return "authentication failed during \(operation). Check biometric settings or keychain access."
            }
            return "Keychain \(operation) failed. Check keychain access permissions and try again."
        case .invalidSecretData:
            return "Reset the stored credential and re-enter it."
        }
    }
}

actor KeychainSecretStore: SecretStore {
    private let serviceName: String
    private static let logger = Logger(subsystem: "com.vpstudio", category: "secret-store")
    private var shouldUseNativeStore: Bool
    private var inMemoryValues: [String: String] = [:]

    init(serviceName: String = "com.vpstudio.credentials") {
        self.serviceName = serviceName
        self.shouldUseNativeStore = Self.isNativeKeychainUsable()

        if !shouldUseNativeStore {
            Self.logger.warning("Falling back to in-memory secret storage because native keychain is unavailable.")
        }
    }

    nonisolated static func isNativeKeychainUsable() -> Bool {
        let probeAccount = "__vpstudio_keychain_probe_\(UUID().uuidString)"
        let probeService = "com.vpstudio.credentials.probe"
        let probeQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: probeService,
            kSecAttrAccount as String: probeAccount,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
            kSecValueData as String: Data(),
        ]

        let addStatus = SecItemAdd(probeQuery as CFDictionary, nil)
        if addStatus != errSecSuccess && addStatus != errSecDuplicateItem {
            return false
        }

        let deleteStatus = SecItemDelete(probeQuery as CFDictionary)
        return deleteStatus == errSecSuccess || deleteStatus == errSecItemNotFound
    }

    /// Only statuses that mean "this environment has no usable keychain at all" may
    /// permanently downgrade to the in-memory store. Transient failures (device locked,
    /// `errSecAuthFailed`, `errSecInteractionNotAllowed`, etc.) must NOT flip the store:
    /// `inMemoryValues` is never seeded from the keychain, so flipping on a transient
    /// error would erase every stored secret — including the metadata API key — for the rest
    /// of the session (the cause of keys "disappearing" after a search or some idle time).
    /// Those transient cases instead surface as a thrown `SecretStoreError.unexpectedStatus`
    /// for that single operation, leaving the persisted keychain value intact.
    private static func shouldFallbackToMemory(_ status: OSStatus) -> Bool {
        switch status {
        case errSecNotAvailable, errSecMissingEntitlement:
            return true
        default:
            return false
        }
    }

    private func fallbackToMemoryIfNeeded(_ status: OSStatus, operation: String) -> Bool {
        guard shouldUseNativeStore && Self.shouldFallbackToMemory(status) else { return false }

        shouldUseNativeStore = false
        Self.logger.warning("Native keychain operation '\(operation)' failed with status \(status). Falling back to in-memory storage.")
        return true
    }

    func setSecret(_ secret: String, for key: String) async throws {
        guard shouldUseNativeStore else {
            inMemoryValues[key] = secret
            return
        }

        let encoded = Data(secret.utf8)
        let query = lookupQuery(for: key)
        let update: [String: Any] = [
            kSecValueData as String: encoded,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
        ]

        let updateStatus = SecItemUpdate(query as CFDictionary, update as CFDictionary)
        if updateStatus == errSecSuccess { return }
        if updateStatus != errSecItemNotFound {
            if fallbackToMemoryIfNeeded(updateStatus, operation: "update") {
                inMemoryValues[key] = secret
                return
            }

            throw SecretStoreError.unexpectedStatus(updateStatus, operation: "update")
        }

        var addQuery = lookupQuery(for: key)
        addQuery[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        addQuery[kSecValueData as String] = encoded
        let addStatus = SecItemAdd(addQuery as CFDictionary, nil)

        if fallbackToMemoryIfNeeded(addStatus, operation: "add") {
            inMemoryValues[key] = secret
            return
        }

        guard addStatus == errSecSuccess else {
            throw SecretStoreError.unexpectedStatus(addStatus, operation: "add")
        }
    }

    func getSecret(for key: String) async throws -> String? {
        guard shouldUseNativeStore else {
            return inMemoryValues[key]
        }

        var query = lookupQuery(for: key)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        if status == errSecItemNotFound { return nil }
        if status != errSecSuccess && fallbackToMemoryIfNeeded(status, operation: "read") {
            return inMemoryValues[key]
        }
        guard status == errSecSuccess else {
            throw SecretStoreError.unexpectedStatus(status, operation: "read")
        }
        guard let data = result as? Data, let secret = String(data: data, encoding: .utf8) else {
            throw SecretStoreError.invalidSecretData
        }
        return secret
    }

    func deleteSecret(for key: String) async throws {
        guard shouldUseNativeStore else {
            inMemoryValues[key] = nil
            return
        }

        let status = SecItemDelete(lookupQuery(for: key) as CFDictionary)
        if fallbackToMemoryIfNeeded(status, operation: "delete") {
            inMemoryValues[key] = nil
            return
        }
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw SecretStoreError.unexpectedStatus(status, operation: "delete")
        }
    }

    func deleteAllSecrets() async throws {
        guard shouldUseNativeStore else {
            inMemoryValues.removeAll(keepingCapacity: false)
            return
        }

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecMatchLimit as String: kSecMatchLimitAll,
            kSecReturnAttributes as String: true,
        ]

        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status != errSecSuccess && status != errSecItemNotFound {
            if fallbackToMemoryIfNeeded(status, operation: "deleteAll") {
                inMemoryValues.removeAll(keepingCapacity: false)
                return
            }

            throw SecretStoreError.unexpectedStatus(status, operation: "deleteAll")
        }

        guard status == errSecSuccess else {
            return
        }

        let items: [[String: Any]]
        if let itemArray = result as? [[String: Any]] {
            items = itemArray
        } else if let singleItem = result as? [String: Any] {
            items = [singleItem]
        } else {
            return
        }

        for item in items {
            guard let account = item[kSecAttrAccount as String] as? String else { continue }
            let deleteQuery: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrService as String: serviceName,
                kSecAttrAccount as String: account,
            ]
            let deleteStatus = SecItemDelete(deleteQuery as CFDictionary)
            if fallbackToMemoryIfNeeded(deleteStatus, operation: "deleteAll") {
                inMemoryValues.removeAll(keepingCapacity: false)
                return
            }

            if deleteStatus == errSecInvalidOwnerEdit || deleteStatus == errSecInvalidRecord {
                continue
            }

            if deleteStatus != errSecSuccess && deleteStatus != errSecItemNotFound {
                throw SecretStoreError.unexpectedStatus(deleteStatus, operation: "deleteAll")
            }
        }
    }

    private func lookupQuery(for key: String) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: key,
        ]
    }
}

enum SecretReference {
    static let keychainPrefix = "keychain:"

    nonisolated static func encode(key: String) -> String {
        "\(keychainPrefix)\(key)"
    }

    nonisolated static func decode(_ storedValue: String) -> String? {
        guard storedValue.hasPrefix(keychainPrefix) else { return nil }
        return String(storedValue.dropFirst(keychainPrefix.count))
    }
}

enum SecretKey {
    nonisolated static func setting(_ key: String) -> String {
        "settings.\(key)"
    }

    nonisolated static func debridToken(service: DebridServiceType, configId: String? = nil) -> String {
        if let configId {
            return "debrid.\(service.rawValue).\(configId)"
        }
        return "debrid.\(service.rawValue)"
    }
}
