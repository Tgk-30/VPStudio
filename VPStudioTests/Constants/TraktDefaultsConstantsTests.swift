import Foundation
import Testing
@testable import VPStudio

@Suite("TraktDefaults Constants Tests")
struct TraktDefaultsConstantsTests {

    @Test("Bundled client ID is non-empty")
    func bundledClientIdNotNil() {
        #expect(!TraktDefaults.clientId.isEmpty)
    }

    @Test("Bundled client secret is non-empty")
    func bundledClientSecretNotNil() {
        #expect(!TraktDefaults.clientSecret.isEmpty)
    }

    @Test("hasBundledCredentials returns false for placeholder values")
    func hasBundledCredentialsFalseForPlaceholder() {
        #expect(TraktDefaults.hasBundledCredentials == false)
    }

    @Test("resolvedCredentials returns nil when using placeholders")
    func resolvedCredentialsReturnsNilForPlaceholder() {
        let result = TraktDefaults.resolvedCredentials(
            userClientId: nil,
            userClientSecret: nil
        )
        #expect(result == nil)
    }

    @Test("resolvedCredentials requires both user credential fields")
    func resolvedCredentialsRequiresBothUserCredentialFields() {
        let result = TraktDefaults.resolvedCredentials(
            userClientId: "my-client-id",
            userClientSecret: nil
        )
        #expect(result == nil)
    }

    @Test("resolvedCredentials uses userClientSecret when provided and non-empty")
    func resolvedCredentialsUsesUserClientSecret() {
        let result = TraktDefaults.resolvedCredentials(
            userClientId: "my-client-id",
            userClientSecret: "my-client-secret"
        )
        #expect(result != nil)
        #expect(result?.clientId == "my-client-id")
        #expect(result?.clientSecret == "my-client-secret")
    }

    @Test("resolvedCredentials returns nil when userClientId is empty string")
    func resolvedCredentialsNilForEmptyClientId() {
        let result = TraktDefaults.resolvedCredentials(
            userClientId: "",
            userClientSecret: "secret"
        )
        #expect(result == nil)
    }

    @Test("resolvedCredentials returns nil when userClientSecret is empty string")
    func resolvedCredentialsNilForEmptyClientSecret() {
        let result = TraktDefaults.resolvedCredentials(
            userClientId: "id",
            userClientSecret: ""
        )
        #expect(result == nil)
    }

    @Test("Authorization redirect URI is correct format")
    func authorizationRedirectURI() async throws {
        let service = TraktSyncService(clientId: "test", clientSecret: "test")
        let url = await service.getAuthorizationURL()
        let resolvedURL = try #require(url)
        let components = URLComponents(url: resolvedURL, resolvingAgainstBaseURL: false)
        let redirect = components?.queryItems?.first(where: { $0.name == "redirect_uri" })?.value
        #expect(redirect == "urn:ietf:wg:oauth:2.0:oob")
    }
}
