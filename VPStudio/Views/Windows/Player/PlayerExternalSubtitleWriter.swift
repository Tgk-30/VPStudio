import Foundation

enum PlayerExternalSubtitleWriter {
    static func resolvedFormat(for source: Subtitle) throws -> SubtitleFormat {
        let format = source.format.isSupportedSubtitle
            ? source.format
            : SubtitleFormat.parse(from: source.fileName)
        guard format.isSupportedSubtitle else {
            throw CocoaError(.fileWriteUnsupportedScheme)
        }
        return format
    }

    static func fileURL(
        in directory: URL,
        fileID: String,
        format: SubtitleFormat
    ) -> URL {
        directory
            .appendingPathComponent(fileID)
            .appendingPathExtension(format.fileExtension)
    }

    static func write(
        content: String,
        source: Subtitle,
        directory: URL = FileManager.default.temporaryDirectory,
        fileID: @autoclosure () -> String = UUID().uuidString
    ) throws -> URL {
        let format = try resolvedFormat(for: source)
        let fileURL = fileURL(in: directory, fileID: fileID(), format: format)
        try content.write(to: fileURL, atomically: true, encoding: .utf8)
        return fileURL
    }
}
