import Foundation
import Testing
@testable import VPStudio

@Suite("Library Task Lifecycle")
struct LibraryTaskLifecycleTests {
    @Test
    func libraryViewCancelsLoadTaskOnDisappear() throws {
        let source = try contents(of: "VPStudio/Views/Windows/Library/LibraryView.swift")
        #expect(source.contains(".onDisappear"))
        #expect(source.contains("loadTask?.cancel()"))
        #expect(source.contains("loadTask = nil"))
    }

    @Test
    func folderReorderPersistsAgainstTheListSelectedWhenTheDropCommitted() throws {
        let source = try contents(of: "VPStudio/Views/Windows/Library/LibraryView.swift")
        let body = try functionBody(named: "persistFolderOrder", in: source)

        #expect(body.contains("let listType = selectedList"))
        #expect(body.contains("let loadToken = selectionLoadToken"))
        #expect(body.contains("listType: listType"))
        #expect(body.contains("if selectedList == listType"))
        #expect(body.contains("await loadFolders(loadToken: loadToken)"))
    }

    private func contents(of relativePath: String) throws -> String {
        let absolutePath = repoRootURL().appendingPathComponent(relativePath).path
        return try String(contentsOfFile: absolutePath, encoding: .utf8)
    }

    private func functionBody(named name: String, in source: String) throws -> String {
        guard let nameRange = source.range(of: "private func \(name)") else {
            Issue.record("Missing function \(name)")
            return ""
        }

        guard let openingBrace = source[nameRange.upperBound...].firstIndex(of: "{") else {
            Issue.record("Missing opening brace for \(name)")
            return ""
        }

        var depth = 0
        var index = openingBrace
        while index < source.endIndex {
            let character = source[index]
            if character == "{" {
                depth += 1
            } else if character == "}" {
                depth -= 1
                if depth == 0 {
                    return String(source[openingBrace...index])
                }
            }
            index = source.index(after: index)
        }

        Issue.record("Could not parse function \(name)")
        return ""
    }

    private func repoRootURL() -> URL {
        var url = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
        while !FileManager.default.fileExists(atPath: url.appendingPathComponent("Package.swift").path) {
            let parent = url.deletingLastPathComponent()
            if parent.path == url.path { break }
            url = parent
        }
        return url
    }
}
