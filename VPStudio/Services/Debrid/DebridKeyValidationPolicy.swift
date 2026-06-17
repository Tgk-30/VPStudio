import Foundation

/// Pure, I/O-free format checks for debrid API keys/tokens.
///
/// This mirrors the shape of `DebridHashValidator` (a small static-only
/// validator living alongside the debrid services) but operates on user-pasted
/// API keys instead of torrent info hashes.
///
/// The format check is intentionally CONSERVATIVE: debrid providers use a wide
/// variety of token formats (hex, base64-ish, JWT-style, hyphenated), so the
/// only things rejected here are inputs that *cannot* be a real token — empty
/// or whitespace-only strings, strings containing spaces or control characters,
/// and absurd lengths. Anything that survives those checks is treated as
/// `.plausible`; the authoritative answer comes from a live `validateToken()`
/// call against the provider.
enum DebridKeyValidationPolicy {
    /// Tokens shorter than this are almost certainly truncated/typos; no debrid
    /// provider issues a usable credential this short.
    static let minimumPlausibleLength = 8

    /// Upper bound to reject obviously-illegal pastes (entire documents, etc.).
    /// Generous enough to never reject a real token, including long JWTs.
    static let maximumPlausibleLength = 4096

    enum FormatResult: Equatable, Sendable {
        case empty
        case malformed(reason: String)
        case plausible
    }

    /// Trims surrounding whitespace/newlines so a pasted key with a trailing
    /// newline behaves the same as a cleanly typed one.
    static func normalize(_ key: String) -> String {
        key.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Performs a conservative, offline format check for the given service.
    ///
    /// The `serviceType` is accepted for parity with the rest of the debrid
    /// surface (and to allow future per-provider tightening) but the current
    /// rules are deliberately provider-agnostic so no valid key is ever
    /// rejected before the live check runs.
    static func formatCheck(for serviceType: DebridServiceType, key: String) -> FormatResult {
        let normalized = normalize(key)

        guard !normalized.isEmpty else {
            return .empty
        }

        if normalized.count < minimumPlausibleLength {
            return .malformed(reason: "This key looks too short. Double-check that you pasted the full key.")
        }

        if normalized.count > maximumPlausibleLength {
            return .malformed(reason: "This key looks too long. Make sure you pasted only the API key.")
        }

        // Interior whitespace cannot appear in any debrid token; it almost
        // always means a partial paste or two values concatenated.
        if normalized.unicodeScalars.contains(where: { CharacterSet.whitespacesAndNewlines.contains($0) }) {
            return .malformed(reason: "This key contains spaces. Make sure you pasted only the API key.")
        }

        // Control characters (tabs already covered above, plus other non-printing
        // scalars) are never part of a valid token.
        if normalized.unicodeScalars.contains(where: { CharacterSet.controlCharacters.contains($0) }) {
            return .malformed(reason: "This key contains invalid characters. Re-copy the key and try again.")
        }

        return .plausible
    }
}
