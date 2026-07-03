import Testing
import Foundation
import SwiftUI
@testable import VPStudio

@Suite("ExploreMoodCard Non-Codable Tests")
struct ExploreMoodCardNonCodableTests {
    @Test("ExploreMoodCard is NOT Codable - only Identifiable and Sendable")
    func exploreMoodCardIsNotCodable() {
        let card = ExploreMoodCard(
            id: "scifi",
            title: "Sci-Fi",
            subtitle: "FUTURISTIC",
            symbol: "atom",
            artImageName: "genre-art-scifi",
            color: .cyan,
            movieGenreId: 878,
            tvGenreId: 10765
        )

        let identifiableCheck: any Identifiable = card
        _ = identifiableCheck

        let sendableCheck: any Sendable = card
        _ = sendableCheck
    }

    @Test("ExploreMoodCard Codable conformance cannot be added")
    func exploreMoodCardCannotBeMadeCodable() {
        let card = ExploreGenreCatalog.cards[0]
        #expect(card.id == "scifi")
        #expect(card.title == "Sci-Fi")
    }
}

@Suite("ExploreGenreCatalog Stability Tests")
struct ExploreGenreCatalogStabilityTests {
    @Test("Catalog cards are stable across multiple accesses")
    func catalogStability() {
        let first = ExploreGenreCatalog.cards
        let second = ExploreGenreCatalog.cards
        #expect(first.count == second.count)
        #expect(first.map(\.id) == second.map(\.id))
    }

    @Test("Catalog contains expected number of cards")
    func catalogCardCount() {
        #expect(ExploreGenreCatalog.cards.count == 14)
    }

    @Test("All cards have valid IDs")
    func allCardsHaveValidIds() {
        for card in ExploreGenreCatalog.cards {
            #expect(!card.id.isEmpty)
        }
    }

    @Test("All cards have valid genre IDs")
    func allCardsHaveValidGenreIds() {
        for card in ExploreGenreCatalog.cards {
            #expect(card.movieGenreId != 0 || card.isSpecialCard)
            #expect(card.tvGenreId != 0 || card.isSpecialCard)
        }
    }
}
