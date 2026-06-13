import SwiftUI

struct PlayerStartupStateOverlayView: View {
    let playbackState: PlayerPlaybackState
    let title: String
    let message: String?
    let hasPlayedOnce: Bool
    let hasNextStream: Bool
    let onRetry: () -> Void
    let onTryNextStream: () -> Void

    var body: some View {
        overlayContent
    }

    @ViewBuilder
    private var overlayContent: some View {
        if playbackState == .failed {
            failureOverlay
                .transition(.scale(0.92, anchor: .center).combined(with: .opacity))
        } else if playbackState != .playing && !hasPlayedOnce {
            LoadingOverlay(
                title: title,
                message: message
            )
            .transition(.scale(0.92, anchor: .center).combined(with: .opacity))
        } else if playbackState == .buffering && hasPlayedOnce {
            VStack {
                InlineLoadingStatusView(title: message ?? "Rebuffering...")
                    .padding(.top, 80)
                Spacer()
            }
            .transition(.opacity)
        }
    }

    private var failureOverlay: some View {
        VStack(spacing: 14) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.largeTitle)
                .foregroundStyle(.orange)

            Text(title)
                .font(.headline)
                .foregroundStyle(.white)

            if let message, !message.isEmpty {
                Text(message)
                    .font(.subheadline)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.white.opacity(0.85))
                    .padding(.horizontal, 24)
            }

            HStack(spacing: 10) {
                Button("Retry") {
                    onRetry()
                }
                .buttonStyle(.borderedProminent)

                if hasNextStream {
                    Button("Try Next Stream") {
                        onTryNextStream()
                    }
                    .buttonStyle(.bordered)
                }
            }
        }
        .padding(.vertical, 20)
        .padding(.horizontal, 28)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18))
        .overlay {
            RoundedRectangle(cornerRadius: 18)
                .strokeBorder(
                    LinearGradient(
                        colors: [.white.opacity(0.24), .white.opacity(0.06)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        }
        .shadow(color: .black.opacity(0.07), radius: 24, y: 0)
        .shadow(color: .black.opacity(0.13), radius: 8, y: 4)
    }
}
