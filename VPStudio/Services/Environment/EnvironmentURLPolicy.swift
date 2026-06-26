import Foundation

enum EnvironmentURLPolicy {
    static func webURL(from value: String?, requiresHTTPS: Bool = false) -> URL? {
        guard let rawValue = value?.trimmingCharacters(in: .whitespacesAndNewlines),
              !rawValue.isEmpty,
              let url = URL(string: rawValue),
              let scheme = url.scheme?.lowercased(),
              let host = url.host,
              !host.isEmpty,
              !isLocalOrPrivateNetworkHost(host),
              url.user == nil,
              url.password == nil,
              !SensitiveURLQueryPolicy.containsSensitiveQueryItem(in: url) else {
            return nil
        }

        if requiresHTTPS {
            return scheme == "https" ? url : nil
        }
        return scheme == "http" || scheme == "https" ? url : nil
    }

    private static func isLocalOrPrivateNetworkHost(_ host: String) -> Bool {
        let normalizedHost = host
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: "[]"))
            .trimmingCharacters(in: CharacterSet(charactersIn: "."))
            .lowercased()

        guard !normalizedHost.isEmpty else { return true }
        if normalizedHost == "localhost"
            || normalizedHost.hasSuffix(".localhost")
            || normalizedHost == "local"
            || normalizedHost.hasSuffix(".local") {
            return true
        }

        if isObfuscatedIPv4Host(normalizedHost) {
            return true
        }

        if isPrivateIPv4Host(normalizedHost) {
            return true
        }

        if isPrivateIPv6Host(normalizedHost) {
            return true
        }

        return false
    }

    private static func isObfuscatedIPv4Host(_ host: String) -> Bool {
        guard let parsed = parseIPv4Address(host),
              host != parsed.canonicalDottedDecimal else {
            return false
        }
        return true
    }

    private static func isPrivateIPv4Host(_ host: String) -> Bool {
        guard let parsed = parseIPv4Address(host),
              host == parsed.canonicalDottedDecimal else {
            return false
        }
        return isPrivateIPv4Address(parsed.octets)
    }

    private static func isPrivateIPv4Address(_ octets: [Int]) -> Bool {
        guard octets.count == 4 else { return false }

        let first = octets[0]
        let second = octets[1]
        switch first {
        case 0, 10, 127:
            return true
        case 100:
            return (64...127).contains(second)
        case 169:
            return second == 254
        case 172:
            return (16...31).contains(second)
        case 192:
            return second == 168 || (second == 0 && (octets[2] == 0 || octets[2] == 2))
        case 198:
            return second == 18 || second == 19 || (second == 51 && octets[2] == 100)
        case 203:
            return second == 0 && octets[2] == 113
        case 224...255:
            return true
        default:
            return false
        }
    }

    private static func parseIPv4Address(_ host: String) -> (octets: [Int], canonicalDottedDecimal: String)? {
        let parts = host.split(separator: ".", omittingEmptySubsequences: false).map(String.init)
        guard (1...4).contains(parts.count),
              parts.allSatisfy({ !$0.isEmpty }),
              let values = parseIPv4NumericParts(parts) else {
            return nil
        }

        let packedValue: UInt64
        switch values.count {
        case 1:
            guard values[0] <= 0xFFFF_FFFF else { return nil }
            packedValue = values[0]
        case 2:
            guard values[0] <= 0xFF, values[1] <= 0xFF_FFFF else { return nil }
            packedValue = (values[0] << 24) | values[1]
        case 3:
            guard values[0] <= 0xFF, values[1] <= 0xFF, values[2] <= 0xFFFF else { return nil }
            packedValue = (values[0] << 24) | (values[1] << 16) | values[2]
        case 4:
            guard values.allSatisfy({ $0 <= 0xFF }) else { return nil }
            packedValue = (values[0] << 24) | (values[1] << 16) | (values[2] << 8) | values[3]
        default:
            return nil
        }

        let octets = [
            Int((packedValue >> 24) & 0xFF),
            Int((packedValue >> 16) & 0xFF),
            Int((packedValue >> 8) & 0xFF),
            Int(packedValue & 0xFF),
        ]
        return (octets, octets.map(String.init).joined(separator: "."))
    }

    private static func parseIPv4NumericParts(_ parts: [String]) -> [UInt64]? {
        var values: [UInt64] = []
        values.reserveCapacity(parts.count)
        for part in parts {
            guard let value = parseIPv4NumericPart(part) else { return nil }
            values.append(value)
        }
        return values
    }

    private static func parseIPv4NumericPart(_ part: String) -> UInt64? {
        let value = part.lowercased()
        if value.hasPrefix("0x") {
            let hexDigits = String(value.dropFirst(2))
            guard !hexDigits.isEmpty,
                  hexDigits.allSatisfy(\.isHexDigit) else {
                return nil
            }
            return UInt64(hexDigits, radix: 16)
        }

        if value.count > 1, value.hasPrefix("0") {
            guard value.allSatisfy({ ("0"..."7").contains($0) }) else {
                return nil
            }
            return UInt64(value, radix: 8)
        }

        guard value.allSatisfy(\.isNumber) else { return nil }
        return UInt64(value, radix: 10)
    }

    private static func isPrivateIPv6Host(_ host: String) -> Bool {
        guard host.contains(":") else { return false }

        if let hextets = expandedIPv6Hextets(host) {
            if hextets.allSatisfy({ $0 == 0 })
                || (hextets.dropLast().allSatisfy({ $0 == 0 }) && hextets.last == 1) {
                return true
            }

            if let mappedOctets = ipv4MappedOrCompatibleOctets(from: hextets),
               isPrivateIPv4Address(mappedOctets) {
                return true
            }

            let firstHextet = Int(hextets[0])
            return (firstHextet & 0xFE00) == 0xFC00
                || (firstHextet & 0xFFC0) == 0xFE80
                || (firstHextet & 0xFF00) == 0xFF00
        }

        guard let firstPart = host
            .split(separator: ":", omittingEmptySubsequences: false)
            .first(where: { !$0.isEmpty }),
              let firstHextet = Int(firstPart, radix: 16) else {
            return false
        }

        return (firstHextet & 0xFE00) == 0xFC00
            || (firstHextet & 0xFFC0) == 0xFE80
            || (firstHextet & 0xFF00) == 0xFF00
    }

    private static func expandedIPv6Hextets(_ host: String) -> [UInt16]? {
        let compressionParts = host.components(separatedBy: "::")
        guard compressionParts.count <= 2 else { return nil }

        if compressionParts.count == 1 {
            guard let hextets = parseIPv6HextetSequence(compressionParts[0]),
                  hextets.count == 8 else {
                return nil
            }
            return hextets
        }

        guard let left = parseIPv6HextetSequence(compressionParts[0]),
              let right = parseIPv6HextetSequence(compressionParts[1]) else {
            return nil
        }
        let missingCount = 8 - left.count - right.count
        guard missingCount >= 1 else { return nil }
        return left + Array(repeating: 0, count: missingCount) + right
    }

    private static func parseIPv6HextetSequence(_ value: String) -> [UInt16]? {
        guard !value.isEmpty else { return [] }
        let rawParts = value.split(separator: ":", omittingEmptySubsequences: false).map(String.init)
        guard rawParts.allSatisfy({ !$0.isEmpty }) else { return nil }

        var hextets: [UInt16] = []
        hextets.reserveCapacity(rawParts.count)
        for (index, rawPart) in rawParts.enumerated() {
            if rawPart.contains(".") {
                guard index == rawParts.count - 1,
                      let parsedIPv4 = parseIPv4Address(rawPart) else {
                    return nil
                }
                hextets.append(UInt16(parsedIPv4.octets[0] << 8 | parsedIPv4.octets[1]))
                hextets.append(UInt16(parsedIPv4.octets[2] << 8 | parsedIPv4.octets[3]))
                continue
            }

            guard !rawPart.isEmpty,
                  rawPart.count <= 4,
                  rawPart.allSatisfy(\.isHexDigit),
                  let hextet = UInt16(rawPart, radix: 16) else {
                return nil
            }
            hextets.append(hextet)
        }
        return hextets
    }

    private static func ipv4MappedOrCompatibleOctets(from hextets: [UInt16]) -> [Int]? {
        guard hextets.count == 8,
              hextets.prefix(5).allSatisfy({ $0 == 0 }) else {
            return nil
        }

        guard hextets[5] == 0xFFFF || hextets[5] == 0 else { return nil }
        let high = hextets[6]
        let low = hextets[7]
        return [
            Int((high >> 8) & 0xFF),
            Int(high & 0xFF),
            Int((low >> 8) & 0xFF),
            Int(low & 0xFF),
        ]
    }

    static func absoluteFileURL(fromStoredPath path: String) -> URL? {
        let trimmedPath = path.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedPath.isEmpty,
              (trimmedPath as NSString).isAbsolutePath,
              !trimmedPath.hasPrefix("bundle://") else {
            return nil
        }

        let url = URL(fileURLWithPath: trimmedPath)
        guard url.isFileURL else {
            return nil
        }
        return url
    }

    static func fileURL(_ fileURL: URL, isInside directoryURL: URL) -> Bool {
        let fileComponents = fileURL.standardizedFileURL.resolvingSymlinksInPath().pathComponents
        let directoryComponents = directoryURL.standardizedFileURL.resolvingSymlinksInPath().pathComponents
        guard fileComponents.count > directoryComponents.count else { return false }
        return zip(directoryComponents, fileComponents).allSatisfy { $0 == $1 }
    }

    static func bundleResourceURL(relativePath: String, in bundle: Bundle) -> URL? {
        let relative = relativePath.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        let parts = relative.split(separator: "/", omittingEmptySubsequences: true).map(String.init)
        guard let file = parts.last,
              !file.isEmpty,
              parts.allSatisfy(isSafeBundlePathComponent) else {
            return nil
        }

        let fileURL = URL(fileURLWithPath: file)
        let name = fileURL.deletingPathExtension().lastPathComponent
        let ext = fileURL.pathExtension.isEmpty ? nil : fileURL.pathExtension
        let subdirectory = parts.dropLast().isEmpty ? nil : parts.dropLast().joined(separator: "/")
        return bundle.url(forResource: name, withExtension: ext, subdirectory: subdirectory)
    }

    private static func isSafeBundlePathComponent(_ component: String) -> Bool {
        !component.isEmpty
            && component != "."
            && component != ".."
            && !component.contains("\\")
    }
}
