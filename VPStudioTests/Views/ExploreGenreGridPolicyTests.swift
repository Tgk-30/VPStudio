import SwiftUI
import Testing
@testable import VPStudio

@Suite("Explore Genre Grid Policy")
@MainActor
struct ExploreGenreGridPolicyTests {
    @Test
    func tilePolicyBuildsStableImageNamesAndAccessibilityLabels() throws {
        let card = try #require(ExploreGenreCatalog.cards.first(where: { $0.id == "scifi" }))

        #expect(ExploreGenreTilePolicy.imageName(for: card) == "genre-ref-scifi")
        #expect(ExploreGenreTilePolicy.accessibilityLabel(for: card) == "\(card.title), \(card.subtitle)")
        #expect(ExploreGenreTilePolicy.cornerRadius == 17)
        #expect(abs(ExploreGenreTilePolicy.referenceAspectRatio - CGFloat(227.0 / 251.0)) < 0.0001)
    }

    @Test
    func gridColumnPolicyKeepsExpectedFixedLayout() {
        let columns = ExploreGenreTilePolicy.gridColumns()

        #expect(columns.count == ExploreGenreTilePolicy.columns)
        #expect(ExploreGenreTilePolicy.columns == 7)
        #expect(ExploreGenreTilePolicy.tileWidth == 128)
        #expect(ExploreGenreTilePolicy.columnSpacing == 16)
        #expect(ExploreGenreTilePolicy.rowSpacing == 15)
    }

    @Test
    func gridHostsEmptyAndPopulatedCatalogSlicesWithoutSelection() {
        var selectedCards: [ExploreMoodCard] = []
        let cards = Array(ExploreGenreCatalog.cards.prefix(4))

        let view = VStack(spacing: 24) {
            ExploreGenreGrid(
                cards: [],
                onSelect: { selectedCards.append($0) }
            )

            ExploreGenreGrid(
                cards: cards,
                onSelect: { selectedCards.append($0) }
            )
        }
        .padding()
        .frame(width: 700, height: 440, alignment: .topLeading)
        .background(Color.black)

        SwiftUIViewDiagnosticHost.render(view, width: 700, height: 440)

        #expect(selectedCards.isEmpty)
    }
}
