import Foundation
import Testing
@testable import VPStudio

@Suite("SecretStoreError")
struct SecretStoreErrorTests {

    @Test
    func unexpectedStatusErrorDescription() {
        let err = SecretStoreError.unexpectedStatus(-25300, operation: "read")
        #expect(err.errorDescription?.contains("Keychain read failed") == true)
        #expect(err.errorDescription?.contains("-25300") == true)
    }

    @Test
    func unexpectedStatusRecoverySuggestion() {
        let err = SecretStoreError.unexpectedStatus(errSecAuthFailed, operation: "update")
        #expect(err.recoverySuggestion?.contains("authentication") == true)
    }

    @Test
    func unexpectedStatusWithDeleteOperation() {
        let err = SecretStoreError.unexpectedStatus(errSecItemNotFound, operation: "delete")
        #expect(err.errorDescription?.contains("delete") == true)
    }

    @Test
    func unexpectedStatusWithAddOperation() {
        let err = SecretStoreError.unexpectedStatus(errSecDuplicateItem, operation: "add")
        #expect(err.errorDescription?.contains("add") == true)
    }

    @Test
    func unexpectedStatusEquatable() {
        let errA = SecretStoreError.unexpectedStatus(-1, operation: "read")
        let errB = SecretStoreError.unexpectedStatus(-1, operation: "read")
        let errC = SecretStoreError.unexpectedStatus(-2, operation: "read")
        #expect(errA == errB)
        #expect(errA != errC)
    }

    @Test
    func unexpectedStatusDifferentOperationsAreNotEqual() {
        let errRead = SecretStoreError.unexpectedStatus(-1, operation: "read")
        let errWrite = SecretStoreError.unexpectedStatus(-1, operation: "update")
        #expect(errRead != errWrite)
    }

    @Test
    func invalidSecretDataErrorDescription() {
        let err = SecretStoreError.invalidSecretData
        #expect(err.errorDescription?.contains("invalid") == true)
        #expect(err.errorDescription?.contains("secret") == true)
    }

    @Test
    func invalidSecretDataRecoverySuggestion() {
        let err = SecretStoreError.invalidSecretData
        #expect(err.recoverySuggestion != nil)
    }

    @Test
    func invalidSecretDataEquatable() {
        let errA = SecretStoreError.invalidSecretData
        let errB = SecretStoreError.invalidSecretData
        #expect(errA == errB)
    }

    @Test
    func unexpectedStatusAndInvalidSecretDataAreNotEqual() {
        let errUnexpected = SecretStoreError.unexpectedStatus(-1, operation: "read")
        let errInvalid = SecretStoreError.invalidSecretData
        #expect(errUnexpected != errInvalid)
    }

    @Test
    func errorDescriptionForAllKeychainOperations() {
        let operations = ["add", "update", "read", "delete", "deleteAll"]
        for op in operations {
            let err = SecretStoreError.unexpectedStatus(-1, operation: op)
            #expect(err.errorDescription?.contains(op) == true)
        }
    }

    @Test
    func errorDescriptionForCommonOSStatusCodes() {
        let statusCodes: [OSStatus] = [
            errSecSuccess,
            errSecItemNotFound,
            errSecDuplicateItem,
            errSecAuthFailed,
            errSecParam,
        ]
        for status in statusCodes {
            let err = SecretStoreError.unexpectedStatus(status, operation: "test")
            #expect(err.errorDescription != nil)
            #expect(err.errorDescription?.contains(String(status)) == true)
        }
    }
}