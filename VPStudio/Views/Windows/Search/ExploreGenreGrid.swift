import SwiftUI

enum ExploreGenreTilePolicy {
    static let columns = 7
    static let tileWidth: CGFloat = 128
    static let columnSpacing: CGFloat = 14
    static let rowSpacing: CGFloat = 14
    static let cornerRadius: CGFloat = VPRadius.control
    static let defaultFallbackImageName = "genre-art-deep"
    static let referenceAspectRatio: CGFloat = 128.0 / 142.0
    static let artworkOverscanScale: CGFloat = 1.0
    static let labelFontSize: CGFloat = 14
    static let labelMinimumScale: CGFloat = 0.72
    static let labelHorizontalPadding: CGFloat = 10
    static let labelBottomPadding: CGFloat = 8
    static let labelScrimHeightRatio: CGFloat = 0.44
    static let borderLineWidth: CGFloat = 0.8
    static let borderOpacity: Double = 0.22
    static var tileHeight: CGFloat {
        tileWidth / referenceAspectRatio
    }
    static var maxGridWidth: CGFloat {
        CGFloat(columns) * tileWidth + CGFloat(columns - 1) * columnSpacing
    }

    static func imageName(for card: ExploreMoodCard) -> String {
        if let artImageName = card.artImageName {
            return artImageName
        }

        let catalogFallback = "genre-art-\(card.id)"
        if knownCatalogArtImageNames.contains(catalogFallback) {
            return catalogFallback
        }

        return defaultFallbackImageName
    }

    static func accessibilityLabel(for card: ExploreMoodCard) -> String {
        "\(card.title), \(card.subtitle)"
    }

    static func gridColumns() -> [GridItem] {
        [GridItem(.adaptive(minimum: tileWidth, maximum: tileWidth), spacing: columnSpacing, alignment: .top)]
    }

    static func columnCount(for availableWidth: CGFloat, itemCount: Int) -> Int {
        guard itemCount > 0 else { return 0 }
        guard availableWidth > 0 else { return 1 }
        let rawCount = Int(floor((availableWidth + columnSpacing) / (tileWidth + columnSpacing)))
        return min(max(rawCount, 1), min(columns, itemCount))
    }

    static func rowCount(for itemCount: Int, availableWidth: CGFloat? = nil) -> Int {
        guard itemCount > 0 else { return 0 }
        let resolvedColumns: Int
        if let availableWidth {
            resolvedColumns = columnCount(for: availableWidth, itemCount: itemCount)
        } else {
            resolvedColumns = min(columns, itemCount)
        }
        return (itemCount + resolvedColumns - 1) / resolvedColumns
    }

    static func gridHeight(for itemCount: Int, availableWidth: CGFloat? = nil) -> CGFloat {
        let rows = rowCount(for: itemCount, availableWidth: availableWidth)
        guard rows > 0 else { return 0 }
        return CGFloat(rows) * tileHeight + CGFloat(rows - 1) * rowSpacing
    }

    private static var knownCatalogArtImageNames: Set<String> {
        Set(ExploreGenreCatalog.cards.compactMap(\.artImageName))
    }
}

struct ExploreGenreGrid: View {
    let cards: [ExploreMoodCard]
    let onSelect: (ExploreMoodCard) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Browse Categories")
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundStyle(.white)

            LazyVGrid(
                columns: ExploreGenreTilePolicy.gridColumns(),
                alignment: .center,
                spacing: ExploreGenreTilePolicy.rowSpacing
            ) {
                ForEach(cards) { card in
                    ExploreGenreTile(card: card) {
                        onSelect(card)
                    }
                }
            }
            .frame(maxWidth: ExploreGenreTilePolicy.maxGridWidth, alignment: .leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct ExploreGenreTile: View {
    let card: ExploreMoodCard
    let onSelect: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: onSelect) {
            ZStack {
                Image(ExploreGenreTilePolicy.imageName(for: card))
                    .resizable()
                    .interpolation(.high)
                    .antialiased(true)
                    .scaledToFill()
                    .frame(
                        width: ExploreGenreTilePolicy.tileWidth,
                        height: ExploreGenreTilePolicy.tileHeight
                    )
                    .scaleEffect(ExploreGenreTilePolicy.artworkOverscanScale)
            }
            .frame(
                width: ExploreGenreTilePolicy.tileWidth,
                height: ExploreGenreTilePolicy.tileHeight
            )
            .overlay(alignment: .bottom) {
                LinearGradient(
                    colors: [
                        .clear,
                        .black.opacity(0.34),
                        .black.opacity(0.78),
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: ExploreGenreTilePolicy.tileHeight * ExploreGenreTilePolicy.labelScrimHeightRatio)
            }
            .overlay(alignment: .bottom) {
                Text(card.title)
                    .font(.system(
                        size: ExploreGenreTilePolicy.labelFontSize,
                        weight: .semibold,
                        design: .rounded
                    ))
                    .foregroundStyle(.white.opacity(0.94))
                    .lineLimit(1)
                    .minimumScaleFactor(ExploreGenreTilePolicy.labelMinimumScale)
                    .multilineTextAlignment(.center)
                    .frame(
                        width: ExploreGenreTilePolicy.tileWidth
                            - ExploreGenreTilePolicy.labelHorizontalPadding * 2,
                        alignment: .center
                    )
                    .shadow(color: .black.opacity(0.72), radius: 4, y: 1)
                    .padding(.bottom, ExploreGenreTilePolicy.labelBottomPadding)
            }
            .clipShape(tileShape)
            .overlay {
                tileShape
                    .strokeBorder(
                        .white.opacity(ExploreGenreTilePolicy.borderOpacity),
                        lineWidth: ExploreGenreTilePolicy.borderLineWidth
                    )
            }
            .contentShape(tileShape)
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(ExploreGenreTilePolicy.accessibilityLabel(for: card)))
        #if os(visionOS)
        .hoverEffect(.lift)
        #else
        .scaleEffect(isHovered ? 1.03 : 1.0)
        .onHover { hovering in
            withAnimation(.spring(response: 0.28, dampingFraction: 0.78)) {
                isHovered = hovering
            }
        }
        #endif
    }

    private var tileShape: RoundedRectangle {
        RoundedRectangle(cornerRadius: ExploreGenreTilePolicy.cornerRadius, style: .continuous)
    }
}
