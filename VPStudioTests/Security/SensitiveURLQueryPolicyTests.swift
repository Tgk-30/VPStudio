import Foundation
import Testing
@testable import VPStudio

@Suite("Sensitive URL Query Policy")
struct SensitiveURLQueryPolicyTests {
    @Test func recognizesSharedSecretQueryAliasesCaseInsensitively() {
        let names = [
            "apikey",
            "apiKey",
            "api-key",
            "access_token",
            "accessToken",
            "auth_token",
            "authToken",
            "client_secret",
            "clientSecret",
            "id_token",
            "idToken",
            "jwt_token",
            "private_key",
            "refresh_token",
            "refreshToken",
            "secret_key",
            "session_id",
            "sessionId",
            "x-amz-signature",
        ]

        for name in names {
            #expect(SensitiveURLQueryPolicy.isSensitiveName(name))
            #expect(SensitiveURLQueryPolicy.isSensitiveName(name.uppercased()))
        }
    }

    @Test func preservesBenignNamesAndSubstrings() {
        let names = [
            "q",
            "title",
            "monkey",
            "keyframe",
            "tokenized",
            "session_title",
            "signature_name",
        ]

        for name in names {
            #expect(!SensitiveURLQueryPolicy.isSensitiveName(name))
        }
    }

    @Test func detectsSecretQueryItemsWithoutSubstringFalsePositives() throws {
        let secretURL = try #require(URL(string: "https://example.com/poster.jpg?clientSecret=value&q=movie"))
        let benignURL = try #require(URL(string: "https://example.com/poster.jpg?monkey=banana&keyframe=12&session_title=movie"))

        #expect(SensitiveURLQueryPolicy.containsSensitiveQueryItem(in: secretURL))
        #expect(!SensitiveURLQueryPolicy.containsSensitiveQueryItem(in: benignURL))
    }

    @Test func exposesEscapedAssignmentNamesForErrorRedactionRegexes() throws {
        let regex = try NSRegularExpression(
            pattern: #"(?i)(?<![A-Za-z0-9_-])(?:"# + SensitiveURLQueryPolicy.assignmentNameAlternationPattern + #")=([^\s&]+)"#,
            options: []
        )
        let message = "clientSecret=secret monkey=banana refresh-token=refresh idToken=id"
        let nsRange = NSRange(message.startIndex..<message.endIndex, in: message)
        let matches = regex.matches(in: message, range: nsRange)

        #expect(matches.count == 3)
    }
}
