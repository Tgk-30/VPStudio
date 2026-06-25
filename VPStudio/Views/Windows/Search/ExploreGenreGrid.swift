import SwiftUI

enum ExploreGenreTilePolicy {
    static let columns = 6
    static let tileWidth: CGFloat = 152
    static let columnSpacing: CGFloat = 16
    static let rowSpacing: CGFloat = 15
    static let cornerRadius: CGFloat = VPRadius.control
    static let referenceAspectRatio: CGFloat = 128.0 / 142.0
    static let artworkOverscanScale: CGFloat = 1.16
    static var tileHeight: CGFloat {
        tileWidth / referenceAspectRatio
    }

    static func imageName(for card: ExploreMoodCard) -> String {
        "genre-ref-\(card.id)"
    }

    static func accessibilityLabel(for card: ExploreMoodCard) -> String {
        "\(card.title), \(card.subtitle)"
    }

    static func gridColumns() -> [GridItem] {
        Array(
            repeating: GridItem(.fixed(tileWidth), spacing: columnSpacing, alignment: .top),
            count: columns
        )
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
                    .scaledToFit()
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
            .clipShape(tileShape)
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
