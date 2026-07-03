import Foundation

enum SensitiveURLQueryPolicy {
    private static let bearerTokenPattern = regularExpression(
        pattern: #"(?i)\bBearer\s+([A-Za-z0-9._~+/=-]+)"#,
        options: []
    )

    private static let sensitiveQueryItemNames: Set<String> = [
        "access_token",
        "access-token",
        "accesstoken",
        "api_key",
        "api-key",
        "apikey",
        "auth",
        "auth_token",
        "auth-token",
        "authorization",
        "authtoken",
        "bearer",
        "client_secret",
        "client-secret",
        "clientsecret",
        "credential",
        "credentials",
        "id_token",
        "id-token",
        "idtoken",
        "jwt",
        "jwt_token",
        "jwt-token",
        "jwttoken",
        "key",
        "pass",
        "passwd",
        "password",
        "private_key",
        "private-key",
        "privatekey",
        "pwd",
        "refresh_token",
        "refresh-token",
        "refreshtoken",
        "secret",
        "secret_key",
        "secret-key",
        "secretkey",
        "session",
        "session_id",
        "session-id",
        "sessionid",
        "sig",
        "signature",
        "sid",
        "token",
        "x-amz-credential",
        "x-amz-security-token",
        "x-amz-signature",
        "x-amz-token",
        "x-goog-credential",
        "x-goog-security-token",
        "x-goog-signature",
        "x-ms-sig",
        "x-ms-signature",
    ]

    static let assignmentNameAlternationPattern = sensitiveQueryItemNames
        .sorted { lhs, rhs in
            if lhs.count == rhs.count { return lhs < rhs }
            return lhs.count > rhs.count
        }
        .map(NSRegularExpression.escapedPattern(for:))
        .joined(separator: "|")

    private static let sensitiveAssignmentPresencePattern = regularExpression(
        pattern: #"(?i)(?<![A-Za-z0-9_-])(?:"# + assignmentNameAlternationPattern + #")\s*="#,
        options: []
    )

    static func isSensitiveName(_ name: String) -> Bool {
        sensitiveQueryItemNames.contains(
            name
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .lowercased()
        )
    }

    static func containsSensitiveQueryItem(in url: URL) -> Bool {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let queryItems = components.queryItems else {
            return false
        }

        return queryItems.contains { item in
            isSensitiveName(item.name)
        }
    }

    static func containsSensitiveAssignment(in value: String) -> Bool {
        guard let sensitiveAssignmentPresencePattern else {
            return true
        }

        let candidates = [value, value.removingPercentEncoding ?? value]
        return candidates.contains { candidate in
            let nsRange = NSRange(candidate.startIndex..<candidate.endIndex, in: candidate)
            return sensitiveAssignmentPresencePattern.firstMatch(in: candidate, options: [], range: nsRange) != nil
        }
    }

    static func redactedBearerTokens(in message: String) -> String {
        guard let bearerTokenPattern else { return message }
        let nsRange = NSRange(message.startIndex..<message.endIndex, in: message)
        let matches = bearerTokenPattern.matches(in: message, options: [], range: nsRange)
        guard !matches.isEmpty else { return message }

        var redacted = message
        for match in matches.reversed() {
            guard match.numberOfRanges > 1,
                  let valueRange = Range(match.range(at: 1), in: redacted) else {
                continue
            }
            redacted.replaceSubrange(valueRange, with: "REDACTED")
        }
        return redacted
    }

    static func regularExpression(
        pattern: String,
        options: NSRegularExpression.Options = []
    ) -> NSRegularExpression? {
        try? NSRegularExpression(pattern: pattern, options: options)
    }
}
