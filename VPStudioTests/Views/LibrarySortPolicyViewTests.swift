import Testing
@testable import VPStudio

@Suite("LibrarySortPolicy Sort Options")
struct LibrarySortPolicyOptionTests {
    @Test("Date added descending display name")
    func dateAddedDescName() {
        #expect(LibrarySortOption.dateAddedDesc.displayName == "Recently Added")
    }

    @Test("Date added ascending display name")
    func dateAddedAscName() {
        #expect(LibrarySortOption.dateAddedAsc.displayName == "Oldest Added")
    }

    @Test("Title ascending display name")
    func titleAscName() {
        #expect(LibrarySortOption.titleAsc.displayName == "Title A\u{2013}Z")
    }

    @Test("Title descending display name")
    func titleDescName() {
        #expect(LibrarySortOption.titleDesc.displayName == "Title Z\u{2013}A")
    }

    @Test("Year descending display name")
    func yearDescName() {
        #expect(LibrarySortOption.yearDesc.displayName == "Newest Release")
    }

    @Test("Year ascending display name")
    func yearAscName() {
        #expect(LibrarySortOption.yearAsc.displayName == "Oldest Release")
    }

    @Test("All sort options have non-empty display names")
    func allDisplayNamesNonEmpty() {
        for option in LibrarySortOption.allCases {
            #expect(!option.displayName.isEmpty, "Display name for \(option) should be non-empty")
        }
    }

    @Test("Date added options use clock symbols")
    func dateAddedSymbols() {
        #expect(LibrarySortOption.dateAddedDesc.symbolName == "clock.arrow.circlepath")
        #expect(LibrarySortOption.dateAddedAsc.symbolName == "clock")
    }

    @Test("Title options use abc symbols")
    func titleSymbols() {
        #expect(LibrarySortOption.titleAsc.symbolName == "textformat.abc")
        #expect(LibrarySortOption.titleDesc.symbolName == "textformat.abc")
    }

    @Test("Year options use calendar symbols")
    func yearSymbols() {
        #expect(LibrarySortOption.yearDesc.symbolName == "calendar")
        #expect(LibrarySortOption.yearAsc.symbolName == "calendar")
    }

    @Test("All sort options have non-empty symbol names")
    func allSymbolNamesNonEmpty() {
        for option in LibrarySortOption.allCases {
            #expect(!option.symbolName.isEmpty, "Symbol name for \(option) should be non-empty")
        }
    }

    @Test("Sort options are case iterable with expected count")
    func caseIterableCount() {
        #expect(LibrarySortOption.allCases.count == 6)
    }
}
