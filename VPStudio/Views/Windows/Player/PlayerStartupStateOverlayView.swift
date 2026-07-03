import SwiftUI

enum PlayerStartupFailureOverlayPolicy {
    static let maxWidth: CGFloat = 420
    static let cornerRadius: CGFloat = 12
    static let horizontalPadding: CGFloat = 24
    static let verticalPadding: CGFloat = 20
    static let messageLineLimit = 4
}

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
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.85)

            if let message, !message.isEmpty {
                Text(message)
                    .font(.subheadline)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.white.opacity(0.85))
                    .lineLimit(PlayerStartupFailureOverlayPolicy.messageLineLimit)
                    .truncationMode(.tail)
                    .fixedSize(horizontal: false, vertical: true)
            }

            ViewThatFits(in: .horizontal) {
                HStack(spacing: 10) {
                    failureActions
                }
                VStack(spacing: 10) {
                    failureActions
                }
            }
            .controlSize(.regular)
        }
        .frame(maxWidth: PlayerStartupFailureOverlayPolicy.maxWidth)
        .padding(.vertical, PlayerStartupFailureOverlayPolicy.verticalPadding)
        .padding(.horizontal, PlayerStartupFailureOverlayPolicy.horizontalPadding)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: PlayerStartupFailureOverlayPolicy.cornerRadius))
        .overlay {
            RoundedRectangle(cornerRadius: PlayerStartupFailureOverlayPolicy.cornerRadius)
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

    @ViewBuilder
    private var failureActions: some View {
        Button {
            onRetry()
        } label: {
            Label("Retry", systemImage: "arrow.clockwise")
        }
        .buttonStyle(.borderedProminent)

        if hasNextStream {
            Button {
                onTryNextStream()
            } label: {
                Label("Try Next", systemImage: "forward.end.fill")
            }
            .accessibilityLabel("Try next stream")
            .buttonStyle(.bordered)
        }
    }
}
