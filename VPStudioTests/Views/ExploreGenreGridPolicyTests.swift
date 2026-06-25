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
        #expect(ExploreGenreTilePolicy.cornerRadius == VPRadius.control)
        #expect(abs(ExploreGenreTilePolicy.referenceAspectRatio - CGFloat(128.0 / 142.0)) < 0.0001)
        #expect(abs(ExploreGenreTilePolicy.artworkOverscanScale - 1.16) < 0.0001)
        #expect(abs(ExploreGenreTilePolicy.tileHeight - (ExploreGenreTilePolicy.tileWidth / ExploreGenreTilePolicy.referenceAspectRatio)) < 0.0001)
    }

    @Test
    func gridColumnPolicyKeepsExpectedFixedLayout() {
        let columns = ExploreGenreTilePolicy.gridColumns()

        #expect(columns.count == ExploreGenreTilePolicy.columns)
        #expect(ExploreGenreTilePolicy.columns == 6)
        #expect(ExploreGenreTilePolicy.tileWidth == 152)
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

    @Test
    func tileImageScalingUsesSingleFitPolicy() throws {
        let source = try sourceContents(of: "VPStudio/Views/Windows/Search/ExploreGenreGrid.swift")

        #expect(source.contains(".scaledToFit()"))
        #expect(source.contains(".scaleEffect(ExploreGenreTilePolicy.artworkOverscanScale)"))
        #expect(source.contains("height: ExploreGenreTilePolicy.tileHeight"))
        #expect(!source.contains(".scaledToFill()"))
        #expect(!source.contains(".aspectRatio(ExploreGenreTilePolicy.referenceAspectRatio"))
    }

    @Test
    func tileOverscanCropsPastReferenceArtworkRim() {
        let sourceWidthAt3x: CGFloat = 384
        let sourceHeightAt3x: CGFloat = 426
        let visibleSourceWidth = sourceWidthAt3x / ExploreGenreTilePolicy.artworkOverscanScale
        let visibleSourceHeight = sourceHeightAt3x / ExploreGenreTilePolicy.artworkOverscanScale
        let horizontalInset = (sourceWidthAt3x - visibleSourceWidth) / 2
        let verticalInset = (sourceHeightAt3x - visibleSourceHeight) / 2

        #expect(horizontalInset >= 26)
        #expect(verticalInset >= 29)
        #expect(horizontalInset < 32)
        #expect(verticalInset < 36)
    }

    @Test
    func tileImageDoesNotRestrokeFinishedReferenceArtwork() throws {
        let source = try sourceContents(of: "VPStudio/Views/Windows/Search/ExploreGenreGrid.swift")
        let tileBody = try #require(source.slice(from: "private struct ExploreGenreTile", to: "#if os(visionOS)"))

        #expect(!tileBody.contains(".strokeBorder("))
        #expect(!tileBody.contains(".blendMode(.screen)"))
        #expect(!tileBody.contains(".shadow("))
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
