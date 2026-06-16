import SwiftUI

struct SettingsDestinationRow: View {
    let destination: SettingsDestination
    let status: SettingsDestinationStatus?
    let isRecent: Bool

    private var indicatorStatus: SettingsRowIndicatorPolicy.StatusKind {
        guard let status else { return .disabled }
        return SettingsRowIndicatorPolicy.statusKind(from: status.kind)
    }

    private var destinationTint: Color { destination.tintColor }

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(destinationTint.opacity(0.16))
                    .overlay {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .strokeBorder(destinationTint.opacity(0.38), lineWidth: 0.8)
                    }

                Image(systemName: destination.icon)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(destinationTint)

                // Indicator dot overlay
                if SettingsRowIndicatorPolicy.shouldShowIndicator(for: indicatorStatus) {
                    Circle()
                        .fill(SettingsRowIndicatorPolicy.indicatorColor(for: indicatorStatus))
                        .frame(width: 8, height: 8)
                        .shadow(color: SettingsRowIndicatorPolicy.indicatorColor(for: indicatorStatus).opacity(0.5), radius: 3)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                        .offset(x: 2, y: -2)
                }
            }
            .frame(width: 36, height: 36)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(destination.title)
                        .font(.headline)
                    if isRecent {
                        GlassTag(text: "Recent", weight: .semibold)
                    }
                }

                Text(destination.summary)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            Spacer(minLength: 8)

            if let status {
                statusBadge(status)
            }
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            SettingsAccessibilityPolicy.rowLabel(
                title: destination.title,
                status: accessibilityStatus
            )
        )
        .accessibilityHint(
            SettingsAccessibilityPolicy.rowHint(hasWarning: status?.kind == .warning)
        )
    }

    private var accessibilityStatus: String? {
        var components: [String] = []
        if isRecent {
            components.append("Recent")
        }
        if let statusMessage = status?.message, !statusMessage.isEmpty {
            components.append(statusMessage)
        }
        return components.isEmpty ? nil : components.joined(separator: ", ")
    }

    private func statusBadge(_ status: SettingsDestinationStatus) -> some View {
        Text(status.message)
            .font(.caption2.weight(.semibold))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .foregroundStyle(statusForeground(status.kind))
            .background(statusBackground(status.kind), in: Capsule())
    }

    private func statusForeground(_ kind: SettingsStatusKind) -> Color {
        switch kind {
        case .positive: return .green
        case .warning: return .orange
        case .neutral: return .secondary
        }
    }

    private func statusBackground(_ kind: SettingsStatusKind) -> Color {
        switch kind {
        case .positive: return .green.opacity(0.14)
        case .warning: return .orange.opacity(0.14)
        case .neutral: return .white.opacity(0.08)
        }
    }
}

extension SettingsDestination {
    /// Distinct per-category accent so Settings reads as a varied catalog (iOS Settings
    /// style) instead of a wall of identical red "alert" tiles. Used by the obsidian
    /// `VPRow` icons and the legacy destination row alike.
    var tintColor: Color {
        switch self {
        case .debrid: return .blue
        case .indexers: return .teal
        case .metadata: return .green
        case .ai: return .purple
        case .trakt: return .pink
        case .simkl: return .indigo
        case .imdbImport: return Color(red: 0.96, green: 0.77, blue: 0.10)
        case .player: return .orange
        case .subtitles: return .cyan
        case .environments: return .mint
        case .library: return .blue
        case .downloads: return .green
        case .resetData: return .red
        case .testMode: return .gray
        }
    }
}
