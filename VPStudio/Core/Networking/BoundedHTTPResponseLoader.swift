import Foundation

enum BoundedHTTPResponseError: LocalizedError, Equatable {
    case responseTooLarge(limitBytes: Int, receivedBytes: Int)
    case declaredResponseTooLarge(limitBytes: Int, declaredBytes: Int64)

    var errorDescription: String? {
        switch self {
        case .responseTooLarge(let limitBytes, let receivedBytes):
            return "HTTP response exceeded the \(limitBytes)-byte budget after receiving \(receivedBytes) bytes."
        case .declaredResponseTooLarge(let limitBytes, let declaredBytes):
            return "HTTP response declared \(declaredBytes) bytes, which exceeds the \(limitBytes)-byte budget."
        }
    }
}

enum HTTPResponseBudget {
    static let metadataProvider = 2 * 1024 * 1024
    static let indexer = 5 * 1024 * 1024
    static let subtitleMetadata = 2 * 1024 * 1024
    static let debridProvider = 2 * 1024 * 1024
    static let aiProvider = 6 * 1024 * 1024
    static let modelRevisionMetadata = 256 * 1024
    static let syncProvider = 2 * 1024 * 1024
}

enum BoundedHTTPResponseLoader {
    static func data(
        for request: URLRequest,
        session: URLSession,
        delegate: (any URLSessionTaskDelegate)? = nil,
        maximumBytes: Int
    ) async throws -> (Data, URLResponse) {
        let (bytes, response) = try await session.bytes(for: request, delegate: delegate)
        if response.expectedContentLength > Int64(maximumBytes) {
            throw BoundedHTTPResponseError.declaredResponseTooLarge(
                limitBytes: maximumBytes,
                declaredBytes: response.expectedContentLength
            )
        }

        var data = Data()
        data.reserveCapacity(min(maximumBytes, max(0, Int(response.expectedContentLength))))

        for try await byte in bytes {
            data.append(byte)
            if data.count > maximumBytes {
                throw BoundedHTTPResponseError.responseTooLarge(
                    limitBytes: maximumBytes,
                    receivedBytes: data.count
                )
            }
        }
        return (data, response)
    }

    static func data(
        from url: URL,
        session: URLSession,
        maximumBytes: Int
    ) async throws -> (Data, URLResponse) {
        try await data(
            for: URLRequest(url: url),
            session: session,
            maximumBytes: maximumBytes
        )
    }
}
