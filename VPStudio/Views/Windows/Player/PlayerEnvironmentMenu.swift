#if os(visionOS)
import SwiftUI

enum PlayerEnvironmentMenuPolicy {
    static func effectiveSelectedAssetID(
        appStateSelectedID: String?,
        assets: [EnvironmentAsset]
    ) -> String? {
        EnvironmentPreviewRowPolicy.effectiveSelectedAssetID(
            appStateSelectedID: appStateSelectedID,
            assets: assets
        )
    }

    static func effectiveSelectedAsset(
        appStateSelectedAsset: EnvironmentAsset?,
        assets: [EnvironmentAsset]
    ) -> EnvironmentAsset? {
        if let appStateSelectedAsset,
           !normalizedID(appStateSelectedAsset.id).isEmpty {
            return appStateSelectedAsset
        }

        guard let selectedID = effectiveSelectedAssetID(
            appStateSelectedID: appStateSelectedAsset?.id,
            assets: assets
        ) else {
            return nil
        }

        return assets.first { normalizedID($0.id) == selectedID }
    }

    static func effectiveSelectedAssetName(
        appStateSelectedAsset: EnvironmentAsset?,
        assets: [EnvironmentAsset]
    ) -> String? {
        let appStateName = appStateSelectedAsset?.name.trimmingCharacters(in: .whitespacesAndNewlines)
        if let appStateName, !appStateName.isEmpty {
            return appStateName
        }

        let catalogName = effectiveSelectedAsset(
            appStateSelectedAsset: appStateSelectedAsset,
            assets: assets
        )?.name.trimmingCharacters(in: .whitespacesAndNewlines)
        return catalogName?.isEmpty == false ? catalogName : nil
    }

    static func cinemaIconName(
        activeEnvironment: EnvironmentType?,
        isImmersiveSpaceOpen: Bool
    ) -> String {
        activeEnvironment == .cinemaEnvironment && isImmersiveSpaceOpen ? "checkmark" : "theatermasks"
    }

    static func menuAssetIconName(
        assetID: String,
        selectedAssetID: String?,
        activeEnvironment: EnvironmentType?,
        sourceType: EnvironmentAssetSourceType
    ) -> String {
        if isAssetSelected(
            assetID: assetID,
            selectedAssetID: selectedAssetID,
            activeEnvironment: activeEnvironment
        ) {
            return "checkmark"
        }
        return sourceType == .bundled ? "circle.fill" : "pano"
    }

    static func standardRoomIconName(isSelected: Bool) -> String {
        isSelected ? "checkmark" : "rectangle.dashed"
    }

    static func isStandardRoomSelected(
        selectedAssetID: String?,
        activeEnvironment: EnvironmentType?,
        isImmersiveSpaceOpen: Bool
    ) -> Bool {
        guard normalizedID(selectedAssetID).isEmpty else { return false }
        return !(activeEnvironment != nil && isImmersiveSpaceOpen)
    }

    static func compactAssetIconName(forAssetPath assetPath: String) -> String {
        PlayerCinemaEnvironmentPolicy.iconName(forAssetPath: assetPath)
    }

    static func compactAssetTrailingIconName(
        assetID: String,
        selectedAssetID: String?,
        activeEnvironment: EnvironmentType?
    ) -> String? {
        // The trailing checkmark tracks the user's persistent *selection* (mirrors
        // `assetStateText`, which still reports "Selected" while Cinema is active),
        // so it stays visible regardless of which environment is currently active.
        isAssetSelection(
            assetID: assetID,
            selectedAssetID: selectedAssetID
        ) ? "checkmark" : nil
    }

    static func standardRoomStateText(
        selectedAssetID: String?,
        activeEnvironment: EnvironmentType?,
        isImmersiveSpaceOpen: Bool
    ) -> String? {
        isStandardRoomSelected(
            selectedAssetID: selectedAssetID,
            activeEnvironment: activeEnvironment,
            isImmersiveSpaceOpen: isImmersiveSpaceOpen
        ) ? "Active now" : nil
    }

    static func cinemaStateText(
        activeEnvironment: EnvironmentType?,
        isImmersiveSpaceOpen: Bool,
        canOpenCinema: Bool = true
    ) -> String? {
        if activeEnvironment == .cinemaEnvironment && isImmersiveSpaceOpen {
            return "Active now"
        }
        return canOpenCinema ? nil : PlayerCinemaEnvironmentPolicy.unavailableMessage
    }

    static func assetStateText(
        assetID: String,
        selectedAssetID: String?,
        activeEnvironment: EnvironmentType?,
        isImmersiveSpaceOpen: Bool
    ) -> String? {
        guard isAssetSelection(
            assetID: assetID,
            selectedAssetID: selectedAssetID
        ) else {
            return nil
        }
        return isAssetEnvironmentActive(
            activeEnvironment: activeEnvironment,
            isImmersiveSpaceOpen: isImmersiveSpaceOpen
        ) ? "Active now" : "Selected"
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

    static func showsEmptyImportedAssetMessage(assets: [EnvironmentAsset]) -> Bool {
        EnvironmentPreviewRowPolicy.shouldShowImportPrompt(environments: assets)
    }

    static func chromeStatusText(
        selectedAssetName: String?,
        activeEnvironment: EnvironmentType?,
        isImmersiveSpaceOpen: Bool
    ) -> String {
        let selectedName = selectedAssetName?.trimmingCharacters(in: .whitespacesAndNewlines)
        let resolvedSelectedName = selectedName?.isEmpty == false ? selectedName : nil

        if isImmersiveSpaceOpen {
            switch activeEnvironment {
            case .cinemaEnvironment:
                return "Cinema Active"
            case .customEnvironment, .hdriSkybox:
                return resolvedSelectedName.map { "\($0) Active" } ?? "Environment Active"
            case nil:
                break
            }
        }

        if let resolvedSelectedName {
            return "\(resolvedSelectedName) Selected"
        }
        return "Standard Room"
    }

    private static func isAssetSelected(
        assetID: String,
        selectedAssetID: String?,
        activeEnvironment: EnvironmentType?
    ) -> Bool {
        isAssetSelection(assetID: assetID, selectedAssetID: selectedAssetID)
            && activeEnvironment != .cinemaEnvironment
    }

    private static func isAssetSelection(
        assetID: String,
        selectedAssetID: String?
    ) -> Bool {
        let normalizedAssetID = normalizedID(assetID)
        guard !normalizedAssetID.isEmpty else { return false }
        return normalizedAssetID == normalizedID(selectedAssetID)
    }

    private static func isAssetEnvironmentActive(
        activeEnvironment: EnvironmentType?,
        isImmersiveSpaceOpen: Bool
    ) -> Bool {
        guard isImmersiveSpaceOpen else { return false }
        switch activeEnvironment {
        case .customEnvironment, .hdriSkybox:
            return true
        case .cinemaEnvironment, nil:
            return false
        }
    }

    private static func normalizedID(_ id: String?) -> String {
        id?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }
}

struct PlayerEnvironmentMenuLabelSpec: Equatable, Sendable {
    let title: String
    let subtitle: String?
    let leadingSystemImage: String
    let trailingSystemImage: String?

    var menuTitle: String {
        guard let subtitle, !subtitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return title
        }
        return "\(title) - \(subtitle)"
    }

    static func cinema(
        activeEnvironment: EnvironmentType?,
        isImmersiveSpaceOpen: Bool,
        canOpenCinema: Bool = true
    ) -> Self {
        Self(
            title: "Cinema Environment",
            subtitle: PlayerEnvironmentMenuPolicy.cinemaStateText(
                activeEnvironment: activeEnvironment,
                isImmersiveSpaceOpen: isImmersiveSpaceOpen,
                canOpenCinema: canOpenCinema
            ),
            leadingSystemImage: PlayerEnvironmentMenuPolicy.cinemaIconName(
                activeEnvironment: activeEnvironment,
                isImmersiveSpaceOpen: isImmersiveSpaceOpen
            ),
            trailingSystemImage: nil
        )
    }

    static func menuAsset(
        _ asset: EnvironmentAsset,
        selectedAssetID: String?,
        activeEnvironment: EnvironmentType?,
        isImmersiveSpaceOpen: Bool
    ) -> Self {
        Self(
            title: asset.name,
            subtitle: PlayerEnvironmentMenuPolicy.assetStateText(
                assetID: asset.id,
                selectedAssetID: selectedAssetID,
                activeEnvironment: activeEnvironment,
                isImmersiveSpaceOpen: isImmersiveSpaceOpen
            ),
            leadingSystemImage: PlayerEnvironmentMenuPolicy.menuAssetIconName(
                assetID: asset.id,
                selectedAssetID: selectedAssetID,
                activeEnvironment: activeEnvironment,
                sourceType: asset.sourceType
            ),
            trailingSystemImage: nil
        )
    }

    static func compactAsset(
        _ asset: EnvironmentAsset,
        selectedAssetID: String?,
        activeEnvironment: EnvironmentType?,
        isImmersiveSpaceOpen: Bool
    ) -> Self {
        Self(
            title: asset.name,
            subtitle: PlayerEnvironmentMenuPolicy.assetStateText(
                assetID: asset.id,
                selectedAssetID: selectedAssetID,
                activeEnvironment: activeEnvironment,
                isImmersiveSpaceOpen: isImmersiveSpaceOpen
            ),
            leadingSystemImage: PlayerEnvironmentMenuPolicy.compactAssetIconName(
                forAssetPath: asset.assetPath
            ),
            trailingSystemImage: PlayerEnvironmentMenuPolicy.compactAssetTrailingIconName(
                assetID: asset.id,
                selectedAssetID: selectedAssetID,
                activeEnvironment: activeEnvironment
            )
        )
    }

    static func standardRoom(
        selectedAssetID: String?,
        activeEnvironment: EnvironmentType?,
        isImmersiveSpaceOpen: Bool
    ) -> Self {
        let isSelected = PlayerEnvironmentMenuPolicy.isStandardRoomSelected(
            selectedAssetID: selectedAssetID,
            activeEnvironment: activeEnvironment,
            isImmersiveSpaceOpen: isImmersiveSpaceOpen
        )
        return Self(
            title: "Standard Room",
            subtitle: PlayerEnvironmentMenuPolicy.standardRoomStateText(
                selectedAssetID: selectedAssetID,
                activeEnvironment: activeEnvironment,
                isImmersiveSpaceOpen: isImmersiveSpaceOpen
            ),
            leadingSystemImage: PlayerEnvironmentMenuPolicy.standardRoomIconName(isSelected: isSelected),
            trailingSystemImage: nil
        )
    }
}

struct PlayerEnvironmentMenuLabel: View {
    let spec: PlayerEnvironmentMenuLabelSpec

    var body: some View {
        HStack(spacing: 8) {
            Label(spec.menuTitle, systemImage: spec.leadingSystemImage)
            if let trailingSystemImage = spec.trailingSystemImage {
                Spacer(minLength: 8)
                Image(systemName: trailingSystemImage)
            }
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

struct PlayerEnvironmentStandardRow: View {
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
    let selectedAssetID: String?
    let activeEnvironment: EnvironmentType?
    let isImmersiveSpaceOpen: Bool
    let action: (EnvironmentAsset) -> Void

    var body: some View {
        Button(action: performAction) {
            PlayerEnvironmentMenuLabel(
                spec: .menuAsset(
                    asset,
                    selectedAssetID: selectedAssetID,
                    activeEnvironment: activeEnvironment,
                    isImmersiveSpaceOpen: isImmersiveSpaceOpen
                )
            )
        }
    }

    func performAction() {
        action(asset)
    }
}

struct PlayerEnvironmentCompactAssetRow: View {
    let asset: EnvironmentAsset
    let selectedAssetID: String?
    let activeEnvironment: EnvironmentType?
    let isImmersiveSpaceOpen: Bool
    let action: (EnvironmentAsset) -> Void

    var body: some View {
        Button(action: performAction) {
            PlayerEnvironmentMenuLabel(
                spec: .compactAsset(
                    asset,
                    selectedAssetID: selectedAssetID,
                    activeEnvironment: activeEnvironment,
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
    var onClear: () -> Void = {}

    @Environment(AppState.self) private var appState

    var body: some View {
        let selectedAssetID = effectiveSelectedAssetID
        Menu {
            PlayerEnvironmentStandardRow(
                spec: .standardRoom(
                    selectedAssetID: selectedAssetID,
                    activeEnvironment: appState.activeEnvironment,
                    isImmersiveSpaceOpen: appState.isImmersiveSpaceOpen
                ),
                action: onClear
            )
            PlayerEnvironmentCinemaRow(
                spec: .cinema(
                    activeEnvironment: appState.activeEnvironment,
                    isImmersiveSpaceOpen: appState.isImmersiveSpaceOpen
                ),
                action: onSelectCinema
            )
            Divider()
            ForEach(assets, id: \.id) { asset in
                PlayerEnvironmentMenuAssetRow(
                    asset: asset,
                    selectedAssetID: selectedAssetID,
                    activeEnvironment: appState.activeEnvironment,
                    isImmersiveSpaceOpen: appState.isImmersiveSpaceOpen,
                    action: onSelect
                )
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

    private var effectiveSelectedAssetID: String? {
        PlayerEnvironmentMenuPolicy.effectiveSelectedAssetID(
            appStateSelectedID: appState.selectedEnvironmentAsset?.id,
            assets: assets
        )
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
    var canOpenCinema = true
    var onClear: () -> Void = {}
    var onShowCinemaSettings: (() -> Void)? = nil
    var onShowPicker: (() -> Void)? = nil

    @Environment(AppState.self) private var appState

    var body: some View {
        let selectedAssetID = effectiveSelectedAssetID
        Menu {
            PlayerEnvironmentStandardRow(
                spec: .standardRoom(
                    selectedAssetID: selectedAssetID,
                    activeEnvironment: appState.activeEnvironment,
                    isImmersiveSpaceOpen: appState.isImmersiveSpaceOpen
                ),
                action: onClear
            )
            PlayerEnvironmentCinemaRow(
                spec: .cinema(
                    activeEnvironment: appState.activeEnvironment,
                    isImmersiveSpaceOpen: appState.isImmersiveSpaceOpen,
                    canOpenCinema: canOpenCinema
                ),
                action: onSelectCinema
            )
            .disabled(!canOpenCinema)
            if let onShowCinemaSettings {
                Button(action: onShowCinemaSettings) {
                    Label("Cinema Settings", systemImage: "slider.horizontal.3")
                }
            }
            Divider()
            if PlayerEnvironmentMenuPolicy.showsEmptyImportedAssetMessage(assets: assets) {
                Text("No imported environments")
                    .foregroundStyle(.secondary)
                    .disabled(true)
            }
            ForEach(assets, id: \.id) { asset in
                PlayerEnvironmentCompactAssetRow(
                    asset: asset,
                    selectedAssetID: selectedAssetID,
                    activeEnvironment: appState.activeEnvironment,
                    isImmersiveSpaceOpen: appState.isImmersiveSpaceOpen,
                    action: onSelect
                )
            }
            if let onShowPicker {
                Button(action: onShowPicker) {
                    Label("Browse Environments", systemImage: "mountain.2")
                }
            }
            if PlayerEnvironmentMenuPolicy.showsExitEnvironment(isImmersiveSpaceOpen: appState.isImmersiveSpaceOpen) {
                Divider()
                PlayerEnvironmentExitRow(role: .destructive, action: onDismiss)
            }
        } label: {
            Label(
                appState.isImmersiveSpaceOpen ? "Room On" : "Room",
                systemImage: PlayerEnvironmentMenuPolicy.triggerIconName(isImmersiveSpaceOpen: appState.isImmersiveSpaceOpen)
            )
                .font(.caption.weight(.semibold))
                .foregroundStyle(appState.isImmersiveSpaceOpen ? .white : .primary)
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
        .accessibilityLabel("Open immersive environments")
        .hoverEffect(.lift)
    }

    private var effectiveSelectedAssetID: String? {
        PlayerEnvironmentMenuPolicy.effectiveSelectedAssetID(
            appStateSelectedID: appState.selectedEnvironmentAsset?.id,
            assets: assets
        )
    }
}
#endif
