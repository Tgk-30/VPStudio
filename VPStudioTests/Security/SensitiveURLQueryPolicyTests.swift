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
            "x-amz-credential",
            "x-amz-security-token",
            "x-amz-signature",
            "x-goog-credential",
            "x-goog-signature",
            "x-ms-sig",
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

    @Test func detectsSensitiveAssignmentsInRawAndPercentEncodedText() {
        #expect(SensitiveURLQueryPolicy.containsSensitiveAssignment(in: "access_token=secret"))
        #expect(SensitiveURLQueryPolicy.containsSensitiveAssignment(in: "route%3Ftoken%3Dsecret"))
        #expect(!SensitiveURLQueryPolicy.containsSensitiveAssignment(in: "/shell-v4.4/#/detail"))
        #expect(!SensitiveURLQueryPolicy.containsSensitiveAssignment(in: "tokenized=true"))
        #expect(!SensitiveURLQueryPolicy.containsSensitiveAssignment(in: "monkey=banana"))
    }

    @Test func redactsStandaloneBearerTokensWithoutRemovingLabel() {
        let message = "Authorization: Bearer abc.def-123_456 next=ok"
        let redacted = SensitiveURLQueryPolicy.redactedBearerTokens(in: message)

        #expect(redacted == "Authorization: Bearer REDACTED next=ok")
        #expect(!redacted.contains("abc.def"))
    }

    @Test func productionSourcesAvoidForcedRegexInitialization() throws {
        for path in try productionSwiftSourcePaths() {
            let source = try String(contentsOfFile: path, encoding: .utf8)
            #expect(!source.contains("try! NSRegularExpression"))
            #expect(!source.contains("try!NSRegularExpression"))
        }
    }
}

private func productionSwiftSourcePaths() throws -> [String] {
    let sourceRoot = repoRootURL().appendingPathComponent("VPStudio")
    guard let enumerator = FileManager.default.enumerator(
        at: sourceRoot,
        includingPropertiesForKeys: [.isRegularFileKey],
        options: [.skipsHiddenFiles]
    ) else {
        return []
    }

    var paths: [String] = []
    for case let url as URL in enumerator {
        guard url.pathExtension == "swift" else { continue }
        let values = try url.resourceValues(forKeys: [.isRegularFileKey])
        guard values.isRegularFile == true else { continue }
        paths.append(url.path)
    }
    return paths.sorted()
}

private func repoRootURL() -> URL {
    var url = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
    while !FileManager.default.fileExists(atPath: url.appendingPathComponent("Package.swift").path) {
        let parent = url.deletingLastPathComponent()
        if parent.path == url.path { break }
        url = parent
    }
    return url
}
