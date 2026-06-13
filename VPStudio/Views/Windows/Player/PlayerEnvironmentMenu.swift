#if os(visionOS)
import SwiftUI

enum PlayerEnvironmentMenuPolicy {
    static func cinemaIconName(
        activeEnvironment: EnvironmentType?,
        isImmersiveSpaceOpen: Bool
    ) -> String {
        activeEnvironment == .cinemaEnvironment && isImmersiveSpaceOpen ? "checkmark" : "theatermasks"
    }

    static func menuAssetIconName(isActive: Bool, sourceType: EnvironmentAssetSourceType) -> String {
        if isActive { return "checkmark" }
        return sourceType == .bundled ? "circle.fill" : "pano"
    }

    static func compactAssetIconName(forAssetPath assetPath: String) -> String {
        PlayerCinemaEnvironmentPolicy.iconName(forAssetPath: assetPath)
    }

    static func triggerIconName(isImmersiveSpaceOpen: Bool) -> String {
        isImmersiveSpaceOpen ? "mountain.2.fill" : "mountain.2"
    }

    static func showsExitEnvironment(isImmersiveSpaceOpen: Bool) -> Bool {
        isImmersiveSpaceOpen
    }

    static func showsEmptyAssetMessage(assetCount: Int) -> Bool {
        assetCount == 0
    }
}

struct PlayerEnvironmentMenuLabelSpec: Equatable, Sendable {
    let title: String
    let leadingSystemImage: String
    let trailingSystemImage: String?

    static func cinema(
        activeEnvironment: EnvironmentType?,
        isImmersiveSpaceOpen: Bool
    ) -> Self {
        Self(
            title: "Cinema Environment",
            leadingSystemImage: PlayerEnvironmentMenuPolicy.cinemaIconName(
                activeEnvironment: activeEnvironment,
                isImmersiveSpaceOpen: isImmersiveSpaceOpen
            ),
            trailingSystemImage: nil
        )
    }

    static func menuAsset(_ asset: EnvironmentAsset) -> Self {
        Self(
            title: asset.name,
            leadingSystemImage: PlayerEnvironmentMenuPolicy.menuAssetIconName(
                isActive: asset.isActive,
                sourceType: asset.sourceType
            ),
            trailingSystemImage: nil
        )
    }

    static func compactAsset(
        _ asset: EnvironmentAsset,
        selectedAssetID: String?,
        isImmersiveSpaceOpen: Bool
    ) -> Self {
        Self(
            title: asset.name,
            leadingSystemImage: PlayerEnvironmentMenuPolicy.compactAssetIconName(
                forAssetPath: asset.assetPath
            ),
            trailingSystemImage: selectedAssetID == asset.id && isImmersiveSpaceOpen ? "checkmark" : nil
        )
    }
}

struct PlayerEnvironmentMenuLabel: View {
    let spec: PlayerEnvironmentMenuLabelSpec

    var body: some View {
        if let trailingSystemImage = spec.trailingSystemImage {
            HStack {
                Label(spec.title, systemImage: spec.leadingSystemImage)
                Image(systemName: trailingSystemImage)
            }
        } else {
            Label(spec.title, systemImage: spec.leadingSystemImage)
        }
    }
}

struct PlayerEnvironmentCinemaRow: View {
    let spec: PlayerEnvironmentMenuLabelSpec
    let action: () -> Void

    var body: some View {
        Button(action: performAction) {
            PlayerEnvironmentMenuLabel(spec: spec)
        }
    }

    func performAction() {
        action()
    }
}

struct PlayerEnvironmentMenuAssetRow: View {
    let asset: EnvironmentAsset
    let action: (EnvironmentAsset) -> Void

    var body: some View {
        Button(action: performAction) {
            PlayerEnvironmentMenuLabel(spec: .menuAsset(asset))
        }
    }

    func performAction() {
        action(asset)
    }
}

struct PlayerEnvironmentCompactAssetRow: View {
    let asset: EnvironmentAsset
    let selectedAssetID: String?
    let isImmersiveSpaceOpen: Bool
    let action: (EnvironmentAsset) -> Void

    var body: some View {
        Button(action: performAction) {
            PlayerEnvironmentMenuLabel(
                spec: .compactAsset(
                    asset,
                    selectedAssetID: selectedAssetID,
                    isImmersiveSpaceOpen: isImmersiveSpaceOpen
                )
            )
        }
    }

    func performAction() {
        action(asset)
    }
}

struct PlayerEnvironmentExitRow: View {
    let role: ButtonRole?
    let action: () -> Void

    var body: some View {
        Button(role: role, action: performAction) {
            Label("Exit Environment", systemImage: "xmark.circle")
        }
    }

    func performAction() {
        action()
    }
}

/// Isolated subview for the environment picker in the player transport controls.
///
/// By separating this into its own View struct, SwiftUI gives it an independent
/// observation scope. It only re-evaluates when `AppState.isImmersiveSpaceOpen`
/// or `assets` change — not on every engine time-tick that rebuilds the parent.
struct PlayerEnvironmentMenu: View {
    let assets: [EnvironmentAsset]
    let onSelectCinema: () -> Void
    let onSelect: (EnvironmentAsset) -> Void
    let onDismiss: () -> Void

    @Environment(AppState.self) private var appState

    var body: some View {
        Menu {
            PlayerEnvironmentCinemaRow(
                spec: .cinema(
                    activeEnvironment: appState.activeEnvironment,
                    isImmersiveSpaceOpen: appState.isImmersiveSpaceOpen
                ),
                action: onSelectCinema
            )
            Divider()
            ForEach(assets, id: \.id) { asset in
                PlayerEnvironmentMenuAssetRow(asset: asset, action: onSelect)
            }
            if PlayerEnvironmentMenuPolicy.showsExitEnvironment(isImmersiveSpaceOpen: appState.isImmersiveSpaceOpen) {
                Divider()
                PlayerEnvironmentExitRow(role: nil, action: onDismiss)
            }
        } label: {
            Image(systemName: PlayerEnvironmentMenuPolicy.triggerIconName(isImmersiveSpaceOpen: appState.isImmersiveSpaceOpen))
                .font(.title3)
                .foregroundStyle(appState.isImmersiveSpaceOpen ? .blue : .primary)
        }
    }
}

/// Compact environment toggle button for the player top info bar.
///
/// Uses an independent observation scope so it only re-evaluates when
/// `AppState.isImmersiveSpaceOpen` or `assets` changes — not on every
/// engine time-tick that rebuilds the parent view.
struct PlayerEnvironmentButton: View {
    let assets: [EnvironmentAsset]
    let onSelectCinema: () -> Void
    let onSelect: (EnvironmentAsset) -> Void
    let onDismiss: () -> Void

    @Environment(AppState.self) private var appState

    var body: some View {
        Menu {
            PlayerEnvironmentCinemaRow(
                spec: .cinema(
                    activeEnvironment: appState.activeEnvironment,
                    isImmersiveSpaceOpen: appState.isImmersiveSpaceOpen
                ),
                action: onSelectCinema
            )
            Divider()
            if PlayerEnvironmentMenuPolicy.showsEmptyAssetMessage(assetCount: assets.count) {
                Text("No environments available")
            } else {
                ForEach(assets, id: \.id) { asset in
                    PlayerEnvironmentCompactAssetRow(
                        asset: asset,
                        selectedAssetID: appState.selectedEnvironmentAsset?.id,
                        isImmersiveSpaceOpen: appState.isImmersiveSpaceOpen,
                        action: onSelect
                    )
                }
            }
            if PlayerEnvironmentMenuPolicy.showsExitEnvironment(isImmersiveSpaceOpen: appState.isImmersiveSpaceOpen) {
                Divider()
                PlayerEnvironmentExitRow(role: .destructive, action: onDismiss)
            }
        } label: {
            Image(systemName: PlayerEnvironmentMenuPolicy.triggerIconName(isImmersiveSpaceOpen: appState.isImmersiveSpaceOpen))
                .font(.caption.weight(.semibold))
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(
                    appState.isImmersiveSpaceOpen
                        ? AnyShapeStyle(.blue.opacity(0.25))
                        : AnyShapeStyle(.ultraThinMaterial),
                    in: Capsule()
                )
                .overlay {
                    Capsule()
                        .strokeBorder(
                            LinearGradient(
                                colors: appState.isImmersiveSpaceOpen
                                    ? [.blue.opacity(0.6), .blue.opacity(0.2)]
                                    : [.white.opacity(0.28), .white.opacity(0.06)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 0.5
                        )
                }
        }
        .buttonStyle(.plain)
        .hoverEffect(.lift)
    }
}
#endif
