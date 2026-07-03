import SwiftUI
import Testing
@testable import VPStudio

@Suite("Explore Genre Grid Policy")
@MainActor
struct ExploreGenreGridPolicyTests {
    @Test
    func tilePolicyBuildsStableImageNamesAndAccessibilityLabels() throws {
        let card = try #require(ExploreGenreCatalog.cards.first(where: { $0.id == "scifi" }))
        let fallbackCard = ExploreMoodCard(
            id: "custom",
            title: "Custom",
            subtitle: "Fallback",
            symbol: "sparkles",
            artImageName: "missing-artwork",
            color: .cyan,
            movieGenreId: 1,
            tvGenreId: 1
        )

        #expect(ExploreGenreTilePolicy.imageName(for: card) == "genre-art-scifi")
        #expect(ExploreGenreTilePolicy.imageName(for: fallbackCard) == ExploreGenreTilePolicy.defaultFallbackImageName)
        #expect(!ExploreGenreTilePolicy.imageName(for: fallbackCard).hasPrefix("genre-ref-"))
        #expect(ExploreGenreTilePolicy.accessibilityLabel(for: card) == "\(card.title), \(card.subtitle)")
        #expect(ExploreGenreTilePolicy.cornerRadius == VPRadius.control)
        #expect(abs(ExploreGenreTilePolicy.referenceAspectRatio - CGFloat(128.0 / 142.0)) < 0.0001)
        #expect(abs(ExploreGenreTilePolicy.artworkOverscanScale - 1.0) < 0.0001)
        #expect(abs(ExploreGenreTilePolicy.tileHeight - (ExploreGenreTilePolicy.tileWidth / ExploreGenreTilePolicy.referenceAspectRatio)) < 0.0001)
    }

    @Test
    func tilePolicyKeepsFallbacksOnFullBleedGenreArtwork() throws {
        let knownIDFallback = ExploreMoodCard(
            id: "action",
            title: "Action",
            subtitle: "Fallback",
            symbol: "bolt.fill",
            artImageName: "missing-artwork",
            color: .orange,
            movieGenreId: 28,
            tvGenreId: 10759
        )
        let unknownFallback = ExploreMoodCard(
            id: "custom",
            title: "Custom",
            subtitle: "Fallback",
            symbol: "sparkles",
            artImageName: nil,
            color: .cyan,
            movieGenreId: 1,
            tvGenreId: 1
        )
        let source = try sourceContents(of: "VPStudio/Views/Windows/Search/ExploreGenreGrid.swift")

        #expect(knownIDFallback.artImageName == nil)
        #expect(ExploreGenreTilePolicy.imageName(for: knownIDFallback) == "genre-art-action")
        #expect(ExploreGenreTilePolicy.imageName(for: unknownFallback) == ExploreGenreTilePolicy.defaultFallbackImageName)
        #expect(!ExploreGenreTilePolicy.imageName(for: knownIDFallback).hasPrefix("genre-ref-"))
        #expect(!ExploreGenreTilePolicy.imageName(for: unknownFallback).hasPrefix("genre-ref-"))
        #expect(!source.contains("genre-ref-"))
    }

    @Test
    func gridColumnPolicyUsesAdaptiveLayoutCappedAtSevenColumns() {
        let columns = ExploreGenreTilePolicy.gridColumns()

        #expect(columns.count == 1)
        #expect(ExploreGenreTilePolicy.columns == 7)
        #expect(ExploreGenreTilePolicy.tileWidth == 128)
        #expect(ExploreGenreTilePolicy.columnSpacing == 14)
        #expect(ExploreGenreTilePolicy.rowSpacing == 14)
        #expect(ExploreGenreTilePolicy.maxGridWidth == 980)
    }

    @Test
    func fullCatalogFitsInTwoCompleteRowsWhenWideAndWrapsWhenNarrow() {
        let cardCount = ExploreGenreCatalog.cards.count

        #expect(cardCount == 14)
        #expect(ExploreGenreTilePolicy.rowCount(for: cardCount) == 2)
        #expect(ExploreGenreTilePolicy.columnCount(for: ExploreGenreTilePolicy.maxGridWidth, itemCount: cardCount) == 7)
        #expect(ExploreGenreTilePolicy.columnCount(for: 700, itemCount: cardCount) == 5)
        #expect(ExploreGenreTilePolicy.rowCount(for: cardCount, availableWidth: 700) == 3)
        #expect(ExploreGenreTilePolicy.rowCount(for: 0) == 0)
        #expect(
            abs(
                ExploreGenreTilePolicy.gridHeight(for: cardCount)
                - (ExploreGenreTilePolicy.tileHeight * 2 + ExploreGenreTilePolicy.rowSpacing)
            ) < 0.0001
        )
        #expect(
            abs(
                ExploreGenreTilePolicy.gridHeight(for: cardCount, availableWidth: 700)
                - (ExploreGenreTilePolicy.tileHeight * 3 + ExploreGenreTilePolicy.rowSpacing * 2)
            ) < 0.0001
        )
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

    @Test
    func tileImageScalingUsesFillPolicyWithoutOverscan() throws {
        let source = try sourceContents(of: "VPStudio/Views/Windows/Search/ExploreGenreGrid.swift")

        #expect(source.contains(".scaledToFill()"))
        #expect(source.contains(".scaleEffect(ExploreGenreTilePolicy.artworkOverscanScale)"))
        #expect(source.contains("height: ExploreGenreTilePolicy.tileHeight"))
        #expect(!source.contains(".scaledToFit()"))
        #expect(!source.contains(".aspectRatio(ExploreGenreTilePolicy.referenceAspectRatio"))
    }

    @Test
    func tileScalingPreservesReferenceArtworkRimAndLabel() {
        let sourceWidthAt3x: CGFloat = 384
        let sourceHeightAt3x: CGFloat = 426
        let visibleSourceWidth = sourceWidthAt3x / ExploreGenreTilePolicy.artworkOverscanScale
        let visibleSourceHeight = sourceHeightAt3x / ExploreGenreTilePolicy.artworkOverscanScale
        let horizontalInset = (sourceWidthAt3x - visibleSourceWidth) / 2
        let verticalInset = (sourceHeightAt3x - visibleSourceHeight) / 2

        #expect(horizontalInset == 0)
        #expect(verticalInset == 0)
    }

    @Test
    func tileImageUsesSingleNeutralRingInsteadOfNeonRestroke() throws {
        let source = try sourceContents(of: "VPStudio/Views/Windows/Search/ExploreGenreGrid.swift")
        let tileBody = try #require(source.slice(from: "private struct ExploreGenreTile", to: "#if os(visionOS)"))

        #expect(!tileBody.contains(".blendMode(.screen)"))
        #expect(!tileBody.contains("card.color.opacity"))
        #expect(tileBody.contains("ExploreGenreTilePolicy.borderOpacity"))
        #expect(tileBody.contains("ExploreGenreTilePolicy.borderLineWidth"))
    }

    @Test
    func tileRendersOwnLabelAndScrimInsteadOfBakedReferenceText() throws {
        let source = try sourceContents(of: "VPStudio/Views/Windows/Search/ExploreGenreGrid.swift")
        let tileBody = try #require(source.slice(from: "private struct ExploreGenreTile", to: "#if os(visionOS)"))

        #expect(tileBody.contains("Text(card.title)"))
        #expect(tileBody.contains(".minimumScaleFactor(ExploreGenreTilePolicy.labelMinimumScale)"))
        #expect(tileBody.contains(".padding(.bottom, ExploreGenreTilePolicy.labelBottomPadding)"))
        #expect(tileBody.contains("ExploreGenreTilePolicy.labelScrimHeightRatio"))
        #expect(!tileBody.contains("Text(card.subtitle)"))
        #expect(!tileBody.contains("card.color.opacity"))
    }

    private func sourceContents(of relativePath: String) throws -> String {
        let root = repoRootURL()
        return try String(contentsOf: root.appendingPathComponent(relativePath), encoding: .utf8)
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

private extension String {
    func slice(from start: String, to end: String) -> String? {
        guard let startRange = range(of: start),
              let endRange = range(of: end, range: startRange.upperBound..<endIndex)
        else {
            return nil
        }

        return String(self[startRange.lowerBound..<endRange.lowerBound])
    }
}
