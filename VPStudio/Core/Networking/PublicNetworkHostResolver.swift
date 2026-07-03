import Foundation

enum PublicNetworkHostResolver {
    static func resolvesToPrivateOrReservedAddress(host rawHost: String) -> Bool {
        // Redirect screening keeps fail-open semantics: an unresolvable host
        // cannot be proven private, and the connection will fail on its own.
        resolutionFindsPrivateOrReservedAddress(host: rawHost) ?? false
    }

    /// Screens a direct (non-debrid) stream/download destination. Best-effort
    /// and fail-open: an unresolvable host cannot be proven private, and the
    /// policy suites pin allowance for well-formed public URLs regardless of
    /// live DNS so screening stays unit-testable offline. A rebinding attacker
    /// who controls both the addon and its DNS can pass this gate; closing that
    /// requires pinned-address connections, which is an owner-level design
    /// change (documented in the security review).
    static func allowsResolvedDestination(for url: URL) -> Bool {
        guard let host = url.host else {
            return false
        }
        return resolutionFindsPrivateOrReservedAddress(host: host) != true
    }

    /// nil = resolution failed; true/false = whether any resolved address is
    /// private or reserved.
    private static func resolutionFindsPrivateOrReservedAddress(host rawHost: String) -> Bool? {
        let host = rawHost
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: "[]"))
        guard !host.isEmpty else { return true }

        var hints = addrinfo()
        hints.ai_family = AF_UNSPEC
        hints.ai_socktype = SOCK_STREAM

        var result: UnsafeMutablePointer<addrinfo>?
        guard getaddrinfo(host, nil, &hints, &result) == 0, let result else {
            return nil
        }
        defer { freeaddrinfo(result) }

        var current: UnsafeMutablePointer<addrinfo>? = result
        while let info = current {
            if let address = numericHostString(from: info.pointee),
               PrivateNetworkHostPolicy.isPrivateOrReserved(host: address) {
                return true
            }
            current = info.pointee.ai_next
        }
        return false
    }

    private static func numericHostString(from info: addrinfo) -> String? {
        guard let address = info.ai_addr else { return nil }
        var hostBuffer = [CChar](repeating: 0, count: Int(NI_MAXHOST))
        let result = getnameinfo(
            address,
            info.ai_addrlen,
            &hostBuffer,
            socklen_t(hostBuffer.count),
            nil,
            0,
            NI_NUMERICHOST
        )
        guard result == 0 else { return nil }
        let endIndex = hostBuffer.firstIndex(of: 0) ?? hostBuffer.endIndex
        let bytes = hostBuffer[..<endIndex].map { UInt8(bitPattern: $0) }
        return String(decoding: bytes, as: UTF8.self)
    }
}
