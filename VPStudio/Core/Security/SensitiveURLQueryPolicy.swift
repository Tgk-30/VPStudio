import Foundation

enum SensitiveURLQueryPolicy {
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
        "x-amz-signature",
    ]

    static let assignmentNameAlternationPattern = sensitiveQueryItemNames
        .sorted { lhs, rhs in
            if lhs.count == rhs.count { return lhs < rhs }
            return lhs.count > rhs.count
        }
        .map(NSRegularExpression.escapedPattern(for:))
        .joined(separator: "|")

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
}
