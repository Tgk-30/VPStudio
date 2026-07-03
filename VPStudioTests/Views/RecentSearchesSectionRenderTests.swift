import SwiftUI
import Testing
@testable import VPStudio

@Suite("Recent Searches Section Rendering")
@MainActor
struct RecentSearchesSectionRenderTests {
    @Test
    func rendersRecentSearchChipsAndEmptyListWithoutTriggeringCallbacks() {
        var selectedTerms: [String] = []
        var removedTerms: [String] = []
        var clearCount = 0

        let view = VStack(spacing: 18) {
            RecentSearchesSection(
                searches: ["Dune", "Severance", "The Bear"],
                onSelect: { selectedTerms.append($0) },
                onRemove: { removedTerms.append($0) },
                onClear: { clearCount += 1 }
            )

            RecentSearchesSection(
                searches: [],
                onSelect: { selectedTerms.append($0) },
                onRemove: { removedTerms.append($0) },
                onClear: { clearCount += 1 }
            )
        }
        .padding()
        .background(Color.black)

        SwiftUIViewDiagnosticHost.render(view, width: 520, height: 180)

        #expect(selectedTerms.isEmpty)
        #expect(removedTerms.isEmpty)
        #expect(clearCount == 0)
    }
}
