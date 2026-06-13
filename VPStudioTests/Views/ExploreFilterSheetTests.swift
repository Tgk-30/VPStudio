import Foundation
import SwiftUI
import Testing
@testable import VPStudio

#if os(macOS)
import AppKit
#endif

@Suite("ExploreFilterSheet - Language Selection")
@MainActor
struct ExploreFilterSheetLanguageSelectionTests {

    @Test func normalizeSelectionDefaultsToEnglishWhenUnknown() {
        let normalized = ExploreFilterSheetLanguageSelectionPolicy.normalizedSelection(from: ["xx-ZZ"])
        #expect(normalized == ["en-US"])
    }

    @Test func tappingEnglishIsExclusive() {
        let updated = ExploreFilterSheetLanguageSelectionPolicy.selection(
            afterToggling: "en-US",
            in: ["fr-FR", "ja-JP"]
        )

        #expect(updated == ["en-US"])
    }

    @Test func removingLastNonDefaultFallsBackToEnglish() {
        let updated = ExploreFilterSheetLanguageSelectionPolicy.selection(
            afterToggling: "fr-FR",
            in: ["fr-FR"]
        )

        #expect(updated == ["en-US"])
    }

    @Test func selectingNonDefaultFromEnglishClearsEnglishFirst() {
        let updated = ExploreFilterSheetLanguageSelectionPolicy.selection(
            afterToggling: "fr-FR",
            in: ["en-US"]
        )

        #expect(updated == ["fr-FR"])
    }

    @Test func selectingNonDefaultKeepsOtherNonDefaultLanguages() {
        let updated = ExploreFilterSheetLanguageSelectionPolicy.selection(
            afterToggling: "fr-FR",
            in: ["en-US", "ja-JP"]
        )

        #expect(updated == ["en-US", "ja-JP", "fr-FR"])
    }

    @Test func languageToggleRowBodiesBuildForSelectedAndUnselectedStates() {
        let selectedRow = LanguageToggleRow(name: "English", isSelected: true, onTap: {})
        let unselectedRow = LanguageToggleRow(name: "French", isSelected: false, onTap: {})

        _ = selectedRow.body
        _ = unselectedRow.body

        #if os(macOS)
        let host = NSHostingView(
            rootView: VStack {
                selectedRow
                unselectedRow
            }
            .frame(width: 240, height: 80)
        )
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 240, height: 80),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        window.contentView = host
        host.layoutSubtreeIfNeeded()
        RunLoop.main.run(until: Date().addingTimeInterval(0.05))

        #expect(host.fittingSize.width > 0)
        #endif
    }

    #if os(macOS)
    @Test func sheetNormalizesSelectionWhenPresented() {
        var sortOption = DiscoverFilters.SortOption.popularityDesc
        var selectedYear: Int? = nil
        var selectedLanguages: Set<String> = ["xx-ZZ"]
        var selectedGenre: Genre? = nil

        let view = ExploreFilterSheet(
            sortOption: Binding(get: { sortOption }, set: { sortOption = $0 }),
            selectedYear: Binding(get: { selectedYear }, set: { selectedYear = $0 }),
            selectedLanguages: Binding(get: { selectedLanguages }, set: { selectedLanguages = $0 }),
            genres: [Genre(id: 28, name: "Action")],
            selectedGenre: Binding(get: { selectedGenre }, set: { selectedGenre = $0 }),
            displayedSortOptions: [.popularityDesc, .ratingDesc],
            onApply: {}
        )

        let host = NSHostingView(rootView: view.frame(width: 480, height: 640))
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 480, height: 640),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        window.contentView = host
        host.layoutSubtreeIfNeeded()
        RunLoop.main.run(until: Date().addingTimeInterval(0.05))

        #expect(selectedLanguages == ["en-US"])
    }
    #endif
}
