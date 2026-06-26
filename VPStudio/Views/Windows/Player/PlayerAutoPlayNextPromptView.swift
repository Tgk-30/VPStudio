import SwiftUI

enum PlayerAutoPlayNextPromptStylePolicy {
    static let promptMaxWidth: CGFloat = 440
    static let titleColumnMaxWidth: CGFloat = 312
    static let titleLineLimit = 3

    static func primaryButtonOpacity(isResolving: Bool) -> Double {
        isResolving ? 0.52 : 1.0
    }

    static func primaryButtonBackgroundOpacity(isResolving: Bool) -> Double {
        isResolving ? 0.68 : 1.0
    }

    static func secondaryButtonOpacity(isResolving: Bool) -> Double {
        isResolving ? 0.42 : 1.0
    }
}

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
                    .lineLimit(PlayerAutoPlayNextPromptStylePolicy.titleLineLimit)
                    .minimumScaleFactor(0.78)
                    .allowsTightening(true)
                    .fixedSize(horizontal: false, vertical: true)
                    .truncationMode(.tail)

                HStack(spacing: 8) {
                    Button(action: onPlayNow) {
                        HStack(spacing: 6) {
                            if isResolving {
                                ProgressView()
                                    .controlSize(.mini)
                                    .tint(.black)
                            } else {
                                Image(systemName: "play.fill")
                                    .font(.caption.weight(.semibold))
                            }
                            Text(isResolving ? "Loading" : "Play Now")
                                .font(.caption.weight(.semibold))
                        }
                        .foregroundStyle(.black)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(
                            .white.opacity(
                                PlayerAutoPlayNextPromptStylePolicy.primaryButtonBackgroundOpacity(
                                    isResolving: isResolving
                                )
                            ),
                            in: Capsule()
                        )
                        .opacity(PlayerAutoPlayNextPromptStylePolicy.primaryButtonOpacity(isResolving: isResolving))
                    }
                    .buttonStyle(.plain)
                    .disabled(isResolving)
                    .accessibilityLabel(isResolving ? "Loading next episode" : "Play next episode now")

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
                    .opacity(PlayerAutoPlayNextPromptStylePolicy.secondaryButtonOpacity(isResolving: isResolving))
                    .accessibilityLabel("Cancel auto-play")
                }
                .padding(.top, 3)
            }
            .frame(maxWidth: PlayerAutoPlayNextPromptStylePolicy.titleColumnMaxWidth, alignment: .leading)
            .layoutPriority(1)
        }
        .padding(16)
        .frame(maxWidth: PlayerAutoPlayNextPromptStylePolicy.promptMaxWidth, alignment: .leading)
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
