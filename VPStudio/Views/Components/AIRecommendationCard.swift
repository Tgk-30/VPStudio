import SwiftUI

struct AIRecommendationCard: View {
    let recommendation: AIMovieRecommendation
    /// Optional one-tap play affordance. When provided, a primary "Play" button
    /// is rendered that requests playback of the best cached source on open.
    var onPlay: (() -> Void)?

    init(recommendation: AIMovieRecommendation, onPlay: (() -> Void)? = nil) {
        self.recommendation = recommendation
        self.onPlay = onPlay
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top) {
                Text(recommendation.title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .lineLimit(2)
                Spacer()
                if let score = recommendation.score {
                    GlassTag(
                        text: String(format: "%.0f%%", score * 100),
                        tintColor: .purple,
                        weight: .bold
                    )
                }
            }

            HStack(spacing: 6) {
                if let year = recommendation.year {
                    Text(String(year))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                GlassTag(
                    text: recommendation.type == .movie ? "Movie" : "TV",
                    weight: .regular
                )
            }

            if !recommendation.reason.isEmpty {
                Text(recommendation.reason)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
            }

            if let onPlay {
                Button(action: onPlay) {
                    Label("Play", systemImage: "play.fill")
                        .font(.caption.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                        .background(.purple.opacity(0.30), in: Capsule())
                        .overlay(Capsule().stroke(.white.opacity(0.16), lineWidth: 0.8))
                }
                .buttonStyle(.plain)
                .padding(.top, 2)
                .accessibilityLabel("Play \(recommendation.title)")
                .accessibilityHint("Opens the title and plays the best cached source if one is available.")
                #if os(visionOS)
                .hoverEffect(.highlight)
                #endif
            }
        }
        .padding(14)
        .frame(width: 210, alignment: .leading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
        .glassStroke(cornerRadius: 14)
        .glassShadow()
    }
}
