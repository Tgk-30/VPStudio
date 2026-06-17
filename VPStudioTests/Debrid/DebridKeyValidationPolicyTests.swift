import Foundation
import Testing
@testable import VPStudio

@Suite("Debrid Key Validation Policy")
struct DebridKeyValidationPolicyTests {
    @Test func normalizeTrimsSurroundingWhitespace() {
        #expect(DebridKeyValidationPolicy.normalize("  abc123def \n") == "abc123def")
        #expect(DebridKeyValidationPolicy.normalize("\t token-value \t") == "token-value")
        #expect(DebridKeyValidationPolicy.normalize("clean") == "clean")
    }

    @Test func emptyOrWhitespaceOnlyIsEmpty() {
        #expect(DebridKeyValidationPolicy.formatCheck(for: .realDebrid, key: "") == .empty)
        #expect(DebridKeyValidationPolicy.formatCheck(for: .realDebrid, key: "    ") == .empty)
        #expect(DebridKeyValidationPolicy.formatCheck(for: .realDebrid, key: "\n\t ") == .empty)
    }

    @Test func interiorSpacesAreMalformed() {
        let result = DebridKeyValidationPolicy.formatCheck(for: .realDebrid, key: "abcd 1234 efgh")
        guard case .malformed = result else {
            Issue.record("Expected .malformed for a key with interior spaces, got \(result)")
            return
        }
    }

    @Test func controlCharactersAreMalformed() {
        let withTab = "abcd\t12345678"
        let withNewline = "abcd\n12345678"
        let withNull = "abcd\u{0000}12345678"

        for candidate in [withTab, withNewline, withNull] {
            let result = DebridKeyValidationPolicy.formatCheck(for: .allDebrid, key: candidate)
            guard case .malformed = result else {
                Issue.record("Expected .malformed for control-char key \(candidate.debugDescription), got \(result)")
                return
            }
        }
    }

    @Test func tooShortIsMalformed() {
        let result = DebridKeyValidationPolicy.formatCheck(for: .premiumize, key: "abc")
        guard case .malformed = result else {
            Issue.record("Expected .malformed for a too-short key, got \(result)")
            return
        }
    }

    @Test func absurdLengthIsMalformed() {
        let huge = String(repeating: "a", count: DebridKeyValidationPolicy.maximumPlausibleLength + 1)
        let result = DebridKeyValidationPolicy.formatCheck(for: .torBox, key: huge)
        guard case .malformed = result else {
            Issue.record("Expected .malformed for an absurdly long key, got \(result)")
            return
        }
    }

    @Test func realisticTokensArePlausibleAcrossProviders() {
        // A spread of real-world-looking token shapes that must never be rejected.
        let plausibleTokens = [
            "ABCDEFGHIJKLMNOPQRSTUVWXYZ234567",                       // 32-char alphanumeric
            "AbCd1234-EfGh5678-IjKl9012",                             // hyphenated
            "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.payload.signature", // JWT-style
            "sk_live_0123456789abcdefABCDEF",                        // prefixed secret
            "0123456789abcdef0123456789abcdef",                      // hex-ish
        ]

        for provider in DebridServiceType.allCases {
            for token in plausibleTokens {
                #expect(
                    DebridKeyValidationPolicy.formatCheck(for: provider, key: token) == .plausible,
                    "Token \(token) should be plausible for \(provider.rawValue)"
                )
            }
        }
    }

    @Test func pastedKeyWithTrailingNewlineIsPlausible() {
        // Paste-and-go: a trailing newline must not trip the control-char check
        // because normalize() strips it first.
        let pasted = "ABCDEFGHIJKLMNOP1234\n"
        #expect(DebridKeyValidationPolicy.formatCheck(for: .realDebrid, key: pasted) == .plausible)
    }
}
