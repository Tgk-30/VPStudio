import Foundation

enum PlayerStreamURLPolicy {
    static func isPlayable(_ url: URL) -> Bool {
        if url.isFileURL {
            return !url.path.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }

        return TorrentResult.normalizedDirectStreamURLString(url.absoluteString) != nil
    }

    static func permitsResolvedDestination(_ url: URL) -> Bool {
        if url.isFileURL {
            return true
        }
        guard isPlayable(url) else {
            return false
        }
        return PublicNetworkHostResolver.allowsResolvedDestination(for: url)
    }

    static func isPlayable(_ stream: StreamInfo) -> Bool {
        guard URL(string: stream.streamURL.absoluteString) != nil else {
            return false
        }
        return isPlayable(stream.streamURL)
    }

    static func isLaunchable(_ stream: StreamInfo, fileManager: FileManager = .default) -> Bool {
        guard isPlayable(stream) else {
            return false
        }

        guard stream.streamURL.isFileURL else {
            return true
        }

        guard let values = try? stream.streamURL.resourceValues(forKeys: [
            .isRegularFileKey,
            .isSymbolicLinkKey,
            .isDirectoryKey,
        ]) else {
            return false
        }

        return values.isRegularFile == true
            && values.isSymbolicLink != true
            && values.isDirectory != true
            && fileManager.fileExists(atPath: stream.streamURL.path)
    }

    static func allowsRedirect(to request: URLRequest) -> Bool {
        guard let url = request.url else {
            return false
        }
        return permitsResolvedDestination(url)
    }

    static func permitsFinalResponseURL(_ url: URL?) -> Bool {
        guard let url else {
            return false
        }
        return permitsResolvedDestination(url)
    }

    static func sanitizedPlaybackRequestHeaders(_ headers: [String: String]?) -> [String: String] {
        StreamInfo.normalizedRequestHeaders(headers) ?? [:]
    }
}
