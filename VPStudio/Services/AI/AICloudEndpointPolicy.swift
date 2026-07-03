import Foundation

enum AICloudEndpointPolicy {
    static func validatedEndpoint(from value: String) -> URL? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty,
              let url = URL(string: trimmed),
              let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              components.scheme?.lowercased() == "https",
              let host = components.host,
              !host.isEmpty,
              components.user == nil,
              components.password == nil,
              components.fragment == nil,
              components.percentEncodedQuery == nil,
              url.port == nil || url.port == 443,
              !PrivateNetworkHostPolicy.isPrivateOrReserved(host: host),
              !PublicNetworkHostResolver.resolvesToPrivateOrReservedAddress(host: host) else {
            return nil
        }
        return url
    }
}
