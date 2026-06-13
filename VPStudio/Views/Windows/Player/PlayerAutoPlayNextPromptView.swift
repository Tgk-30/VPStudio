import SwiftUI

struct PlayerAutoPlayNextPromptView: View {
    let nextEpisode: PlayerSessionRequest.NextEpisodeCandidate
    let remainingSeconds: Int
    let isResolving: Bool
    let onPlayNow: () -> Void
    let onCancel: () -> Void

    var body: some View {
        HStack(spacing: 16) {
            PlayerAutoPlayCountdownRing(
                progress: PlayerAutoplayNextPolicy.countdownProgress(
                    remainingSeconds: remainingSeconds
                ),
                remainingSeconds: remainingSeconds,
                isResolving: isResolving
            )

            VStack(alignment: .leading, spacing: 5) {
                Text("Up Next")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.70))
                    .textCase(.uppercase)

                Text(nextEpisode.title)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(.white)
                    .lineLimit(2)
                    .minimumScaleFactor(0.82)

                HStack(spacing: 8) {
                    Button(action: onPlayNow) {
                        Label("Play Now", systemImage: "play.fill")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.black)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(.white, in: Capsule())
                    }
                    .buttonStyle(.plain)
                    .disabled(isResolving)

                    Button(action: onCancel) {
                        Image(systemName: "xmark")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.white)
                            .frame(width: 32, height: 32)
                            .background(.white.opacity(0.12), in: Circle())
                            .overlay {
                                Circle()
                                    .strokeBorder(.white.opacity(0.16), lineWidth: 0.8)
                            }
                    }
                    .buttonStyle(.plain)
                    .disabled(isResolving)
                    .accessibilityLabel("Cancel auto-play")
                }
                .padding(.top, 3)
            }
            .frame(maxWidth: 260, alignment: .leading)
        }
        .padding(16)
        .frame(maxWidth: 392, alignment: .leading)
        .background(
            .ultraThinMaterial,
            in: RoundedRectangle(cornerRadius: 22, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(
                    LinearGradient(
                        colors: [.white.opacity(0.28), .white.opacity(0.08)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        }
        .shadow(color: .black.opacity(0.28), radius: 28, y: 12)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
    }

    private var accessibilityLabel: String {
        if isResolving {
            return "Loading \(nextEpisode.title)"
        }

        return "Up next, \(nextEpisode.title), auto-playing in \(remainingSeconds) seconds"
    }
}

struct PlayerAutoPlayCountdownRing: View {
    let progress: Double
    let remainingSeconds: Int
    let isResolving: Bool

    var body: some View {
        ZStack {
            Circle()
                .stroke(.white.opacity(0.16), lineWidth: 5)

            Circle()
                .trim(from: 0, to: CGFloat(progress))
                .stroke(
                    .white,
                    style: StrokeStyle(lineWidth: 5, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))

            if isResolving {
                ProgressView()
                    .controlSize(.small)
                    .tint(.white)
            } else {
                Text("\(remainingSeconds)")
                    .font(.system(size: 18, weight: .semibold, design: .rounded).monospacedDigit())
                    .foregroundStyle(.white)
                    .contentTransition(.numericText())
            }
        }
        .frame(width: 64, height: 64)
        .accessibilityHidden(true)
    }
}
