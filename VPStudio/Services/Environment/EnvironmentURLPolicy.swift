import Foundation

enum EnvironmentURLPolicy {
    static func webURL(from value: String?, requiresHTTPS: Bool = false) -> URL? {
        guard let rawValue = value?.trimmingCharacters(in: .whitespacesAndNewlines),
              !rawValue.isEmpty,
              let url = URL(string: rawValue),
              let scheme = url.scheme?.lowercased(),
              let host = url.host,
              !host.isEmpty,
              url.user == nil,
              url.password == nil else {
            return nil
        }

        if requiresHTTPS {
            return scheme == "https" ? url : nil
        }
        return scheme == "http" || scheme == "https" ? url : nil
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
