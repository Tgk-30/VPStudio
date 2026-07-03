import Foundation
import Testing
@testable import VPStudio

@Suite("ViewModel Error Presentation Policies")
struct ViewModelErrorPresentationPolicyTests {
    @Test
    func detailAndSearchViewModelsSanitizeUserVisibleProviderErrors() throws {
        let detailSource = try contents(of: "VPStudio/ViewModels/Detail/DetailViewModel.swift")
        let searchSource = try contents(of: "VPStudio/ViewModels/Search/SearchViewModel.swift")

        #expect(detailSource.contains("enum DetailErrorPresentationPolicy"))
        #expect(detailSource.contains("IndexerLogSanitizer.redactedErrorMessage(error)"))
        #expect(detailSource.contains("DetailErrorPresentationPolicy.prefixedMessage(\"Rating update failed\", error: error)"))
        #expect(detailSource.contains("DetailErrorPresentationPolicy.prefixedMessage(\"Clear rating failed\", error: error)"))
        #expect(detailSource.contains("aiAnalysisError = DetailErrorPresentationPolicy.displayMessage(for: error)"))
        #expect(!detailSource.contains(".transport(error.localizedDescription)"))
        #expect(!detailSource.contains(".queryFailed(error.localizedDescription)"))
        #expect(!detailSource.contains(".networkError(error.localizedDescription)"))
        #expect(!detailSource.contains("Rating update failed: \\(error.localizedDescription)"))
        #expect(!detailSource.contains("Clear rating failed: \\(error.localizedDescription)"))
        #expect(!detailSource.contains("aiAnalysisError = error.localizedDescription"))

        #expect(searchSource.contains("enum SearchErrorPresentationPolicy"))
        #expect(searchSource.contains("IndexerLogSanitizer.redactedErrorMessage(error)"))
        #expect(searchSource.contains("self.aiError = SearchErrorPresentationPolicy.displayMessage(for: error)"))
        #expect(!searchSource.contains("self.aiError = error.localizedDescription"))
        #expect(!searchSource.contains("error.localizedDescription, privacy: .public"))
    }

    private func contents(of relativePath: String) throws -> String {
        let absolutePath = repoRootURL().appendingPathComponent(relativePath).path
        return try String(contentsOfFile: absolutePath, encoding: .utf8)
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
