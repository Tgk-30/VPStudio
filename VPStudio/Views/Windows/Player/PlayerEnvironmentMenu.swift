#if os(visionOS)
import SwiftUI

enum PlayerEnvironmentMenuPolicy {
    static let triggerDisclosureIconName = "chevron.down"
    static let appleEnvironmentMenuBenefit = "System expansion when available"
    static let appleEnvironmentFallbackBenefit = "Standard window until supported playback is active"
    static let appleEnvironmentPendingBenefit = "Expansion queued until supported playback is active"
    static let appleEnvironmentChromeStatus = "Apple Environment"
    static let appleEnvironmentExpandTitle = "Expand Apple Environment"
    static let appleEnvironmentExpandIconName = "arrow.up.left.and.arrow.down.right"
    static let closeMenuTitle = PlayerCinematicChromePolicy.closeMenuTitle
    static let closeMenuIconName = PlayerCinematicChromePolicy.closeMenuIconName
    static let compactTriggerMinWidth: CGFloat = 170
    static let compactTriggerMaxWidth: CGFloat = 328
    static let compactTriggerMinHeight: CGFloat = PlayerCinematicChromePolicy.quickActionPillMinHeight
    static let compactTriggerMinimumScaleFactor: CGFloat = 0.88
    static let menuRowMinimumScaleFactor: CGFloat = 0.78

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
        EnvironmentPreviewRowPolicy.effectiveSelectedAsset(
            appStateSelectedAsset: appStateSelectedAsset,
            assets: assets
        )
    }

    static func effectiveSelectedAssetName(
        appStateSelectedAsset: EnvironmentAsset?,
        assets: [EnvironmentAsset]
    ) -> String? {
        let selectedName = effectiveSelectedAsset(
            appStateSelectedAsset: appStateSelectedAsset,
            assets: assets
        )?.name.trimmingCharacters(in: .whitespacesAndNewlines)
        return selectedName?.isEmpty == false ? selectedName : nil
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
        isSelected ? "checkmark" : "visionpro"
    }

    static func isStandardRoomSelected(
        selectedAssetID: String?,
        activeEnvironment: EnvironmentType?,
        isImmersiveSpaceOpen: Bool
    ) -> Bool {
        guard normalizedID(selectedAssetID).isEmpty else { return false }
        return activeEnvironment == nil
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
        isImmersiveSpaceOpen: Bool,
        canUseSystemVideoSurface: Bool = true,
        isExpansionPending: Bool = false
    ) -> String? {
        if isStandardRoomSelected(
            selectedAssetID: selectedAssetID,
            activeEnvironment: activeEnvironment,
            isImmersiveSpaceOpen: isImmersiveSpaceOpen
        ) {
            return isExpansionPending ? appleEnvironmentPendingBenefit : "Active now"
        }
        return canUseSystemVideoSurface ? appleEnvironmentMenuBenefit : appleEnvironmentFallbackBenefit
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

    static func triggerIconName(
        selectedAssetID: String?,
        activeEnvironment: EnvironmentType?,
        isImmersiveSpaceOpen: Bool
    ) -> String {
        if usesAppleEnvironmentMode(
            selectedAssetID: selectedAssetID,
            activeEnvironment: activeEnvironment,
            isImmersiveSpaceOpen: isImmersiveSpaceOpen
        ) {
            return "visionpro"
        }
        return triggerIconName(isImmersiveSpaceOpen: isImmersiveSpaceOpen)
    }

    static func triggerTitle(
        selectedAssetID: String?,
        selectedAssetName: String? = nil,
        activeEnvironment: EnvironmentType?,
        isImmersiveSpaceOpen: Bool
    ) -> String {
        if usesAppleEnvironmentMode(
            selectedAssetID: selectedAssetID,
            activeEnvironment: activeEnvironment,
            isImmersiveSpaceOpen: isImmersiveSpaceOpen
        ) {
            return EnvironmentPreviewRowPolicy.appleEnvironmentTitle
        }

        if isImmersiveSpaceOpen {
            return "Environment On"
        }

        if let selectedAssetName = displayableAssetName(selectedAssetName) {
            return selectedAssetName
        }

        return normalizedID(selectedAssetID).isEmpty ? "Environment" : "Environment Selected"
    }

    static func showsExitEnvironment(isImmersiveSpaceOpen: Bool) -> Bool {
        isImmersiveSpaceOpen
    }

    static func showsAppleEnvironmentExpandAction(
        selectedAssetID: String?,
        activeEnvironment: EnvironmentType?,
        isImmersiveSpaceOpen: Bool
    ) -> Bool {
        usesAppleEnvironmentMode(
            selectedAssetID: selectedAssetID,
            activeEnvironment: activeEnvironment,
            isImmersiveSpaceOpen: isImmersiveSpaceOpen
        )
    }

    static func showsEmptyAssetMessage(assetCount: Int) -> Bool {
        assetCount == 0
    }

    static func showsEmptyImportedAssetMessage(assets: [EnvironmentAsset]) -> Bool {
        EnvironmentPreviewRowPolicy.shouldShowImportPrompt(environments: assets)
    }

    static func chromeStatusText(
        selectedAssetName: String?,
        selectedAssetID: String?,
        activeEnvironment: EnvironmentType?,
        isImmersiveSpaceOpen: Bool
    ) -> String {
        if usesAppleEnvironmentMode(
            selectedAssetID: selectedAssetID,
            activeEnvironment: activeEnvironment,
            isImmersiveSpaceOpen: isImmersiveSpaceOpen
        ) {
            return appleEnvironmentChromeStatus
        }

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

        return ""
    }

    static func usesAppleEnvironmentMode(
        selectedAssetID: String?,
        activeEnvironment: EnvironmentType?,
        isImmersiveSpaceOpen: Bool
    ) -> Bool {
        isStandardRoomSelected(
            selectedAssetID: selectedAssetID,
            activeEnvironment: activeEnvironment,
            isImmersiveSpaceOpen: isImmersiveSpaceOpen
        )
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

    private static func displayableAssetName(_ name: String?) -> String? {
        let trimmed = name?.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed?.isEmpty == false ? trimmed : nil
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
        if subtitle == "Active now" || subtitle == "Selected" {
            return title
        }
        if subtitle == PlayerCinemaEnvironmentPolicy.unavailableMessage {
            return "\(title) - Requires supported playback"
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
        isImmersiveSpaceOpen: Bool,
        canUseSystemVideoSurface: Bool = true,
        isExpansionPending: Bool = false
    ) -> Self {
        let isSelected = PlayerEnvironmentMenuPolicy.isStandardRoomSelected(
            selectedAssetID: selectedAssetID,
            activeEnvironment: activeEnvironment,
            isImmersiveSpaceOpen: isImmersiveSpaceOpen
        )
        return Self(
            title: EnvironmentPreviewRowPolicy.appleEnvironmentTitle,
            subtitle: PlayerEnvironmentMenuPolicy.standardRoomStateText(
                selectedAssetID: selectedAssetID,
                activeEnvironment: activeEnvironment,
                isImmersiveSpaceOpen: isImmersiveSpaceOpen,
                canUseSystemVideoSurface: canUseSystemVideoSurface,
                isExpansionPending: isExpansionPending
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
                .lineLimit(1)
                .truncationMode(.tail)
                .minimumScaleFactor(PlayerEnvironmentMenuPolicy.menuRowMinimumScaleFactor)
            if let trailingSystemImage = spec.trailingSystemImage {
                Spacer(minLength: 8)
                Image(systemName: trailingSystemImage)
                    .fixedSize()
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

struct PlayerEnvironmentAppleExpandRow: View {
    let action: () -> Void

    var body: some View {
        Button(action: performAction) {
            Label(
                PlayerEnvironmentMenuPolicy.appleEnvironmentExpandTitle,
                systemImage: PlayerEnvironmentMenuPolicy.appleEnvironmentExpandIconName
            )
        }
    }

    func performAction() {
        action()
    }
}

struct PlayerEnvironmentCloseMenuRow: View {
    let action: () -> Void

    var body: some View {
        Button(action: performAction) {
            Label(
                PlayerEnvironmentMenuPolicy.closeMenuTitle,
                systemImage: PlayerEnvironmentMenuPolicy.closeMenuIconName
            )
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
    var canUseSystemVideoSurface = true
    var isAppleEnvironmentExpansionPending = false
    var onClear: () -> Void = {}
    var onExpandAppleEnvironment: (() -> Void)? = nil
    var onCloseMenu: () -> Void = {}

    @Environment(AppState.self) private var appState

    var body: some View {
        let selectedAssetID = effectiveSelectedAssetID
        Menu {
            PlayerEnvironmentStandardRow(
                spec: .standardRoom(
                    selectedAssetID: selectedAssetID,
                    activeEnvironment: appState.activeEnvironment,
                    isImmersiveSpaceOpen: appState.isImmersiveSpaceOpen,
                    canUseSystemVideoSurface: canUseSystemVideoSurface,
                    isExpansionPending: isAppleEnvironmentExpansionPending
                ),
                action: onClear
            )
            if let onExpandAppleEnvironment,
               PlayerEnvironmentMenuPolicy.showsAppleEnvironmentExpandAction(
                selectedAssetID: selectedAssetID,
                activeEnvironment: appState.activeEnvironment,
                isImmersiveSpaceOpen: appState.isImmersiveSpaceOpen
               ) {
                PlayerEnvironmentAppleExpandRow(action: onExpandAppleEnvironment)
            }
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
            Divider()
            PlayerEnvironmentCloseMenuRow(action: onCloseMenu)
        } label: {
            Image(systemName: PlayerEnvironmentMenuPolicy.triggerIconName(
                selectedAssetID: selectedAssetID,
                activeEnvironment: appState.activeEnvironment,
                isImmersiveSpaceOpen: appState.isImmersiveSpaceOpen
            ))
                .font(.title3)
                .foregroundStyle(appState.isImmersiveSpaceOpen ? VPColor.info : .primary)
        }
        .accessibilityLabel(PlayerEnvironmentMenuPolicy.triggerTitle(
            selectedAssetID: selectedAssetID,
            selectedAssetName: effectiveSelectedAssetName,
            activeEnvironment: appState.activeEnvironment,
            isImmersiveSpaceOpen: appState.isImmersiveSpaceOpen
        ))
    }

    private var effectiveSelectedAssetID: String? {
        PlayerEnvironmentMenuPolicy.effectiveSelectedAssetID(
            appStateSelectedID: appState.selectedEnvironmentAsset?.id,
            assets: assets
        )
    }

    private var effectiveSelectedAssetName: String? {
        PlayerEnvironmentMenuPolicy.effectiveSelectedAssetName(
            appStateSelectedAsset: appState.selectedEnvironmentAsset,
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
    var canUseSystemVideoSurface = true
    var canOpenCinema = true
    var isAppleEnvironmentExpansionPending = false
    var onClear: () -> Void = {}
    var onShowCinemaSettings: (() -> Void)? = nil
    var onShowPicker: (() -> Void)? = nil
    var onExpandAppleEnvironment: (() -> Void)? = nil
    var onCloseMenu: () -> Void = {}

    @Environment(AppState.self) private var appState

    var body: some View {
        let selectedAssetID = effectiveSelectedAssetID
        Menu {
            PlayerEnvironmentStandardRow(
                spec: .standardRoom(
                    selectedAssetID: selectedAssetID,
                    activeEnvironment: appState.activeEnvironment,
                    isImmersiveSpaceOpen: appState.isImmersiveSpaceOpen,
                    canUseSystemVideoSurface: canUseSystemVideoSurface,
                    isExpansionPending: isAppleEnvironmentExpansionPending
                ),
                action: onClear
            )
            if let onExpandAppleEnvironment,
               PlayerEnvironmentMenuPolicy.showsAppleEnvironmentExpandAction(
                selectedAssetID: selectedAssetID,
                activeEnvironment: appState.activeEnvironment,
                isImmersiveSpaceOpen: appState.isImmersiveSpaceOpen
               ) {
                PlayerEnvironmentAppleExpandRow(action: onExpandAppleEnvironment)
            }
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
                PlayerEnvironmentExitRow(role: nil, action: onDismiss)
            }
            Divider()
            PlayerEnvironmentCloseMenuRow(action: onCloseMenu)
        } label: {
            HStack(spacing: 8) {
                Label(
                    PlayerEnvironmentMenuPolicy.triggerTitle(
                        selectedAssetID: selectedAssetID,
                        selectedAssetName: effectiveSelectedAssetName,
                        activeEnvironment: appState.activeEnvironment,
                        isImmersiveSpaceOpen: appState.isImmersiveSpaceOpen
                    ),
                    systemImage: PlayerEnvironmentMenuPolicy.triggerIconName(
                        selectedAssetID: selectedAssetID,
                        activeEnvironment: appState.activeEnvironment,
                        isImmersiveSpaceOpen: appState.isImmersiveSpaceOpen
                    )
                )
                .lineLimit(1)
                .truncationMode(.tail)
                .minimumScaleFactor(PlayerEnvironmentMenuPolicy.compactTriggerMinimumScaleFactor)
                .layoutPriority(1)

                Image(systemName: PlayerEnvironmentMenuPolicy.triggerDisclosureIconName)
                    .font(.footnote.weight(.bold))
                    .foregroundStyle(.white.opacity(0.72))
                    .fixedSize()
                    .accessibilityHidden(true)
            }
                .font(.callout.weight(.semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, PlayerCinematicChromePolicy.quickActionPillHorizontalPadding)
                .padding(.vertical, PlayerCinematicChromePolicy.quickActionPillVerticalPadding)
                .frame(
                    minWidth: PlayerEnvironmentMenuPolicy.compactTriggerMinWidth,
                    maxWidth: PlayerEnvironmentMenuPolicy.compactTriggerMaxWidth,
                    minHeight: PlayerEnvironmentMenuPolicy.compactTriggerMinHeight,
                    alignment: .leading
                )
                .background(
                    appState.isImmersiveSpaceOpen
                        ? AnyShapeStyle(VPColor.info.opacity(0.25))
                        : AnyShapeStyle(.ultraThinMaterial),
                    in: Capsule()
                )
                .overlay {
                    Capsule()
                        .strokeBorder(
                            LinearGradient(
                                colors: appState.isImmersiveSpaceOpen
                                    ? [VPColor.info.opacity(0.6), VPColor.info.opacity(0.2)]
                                    : [.white.opacity(0.28), .white.opacity(0.06)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 0.5
                        )
                }
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Choose playback environment")
        .hoverEffect(.lift)
    }

    private var effectiveSelectedAssetID: String? {
        PlayerEnvironmentMenuPolicy.effectiveSelectedAssetID(
            appStateSelectedID: appState.selectedEnvironmentAsset?.id,
            assets: assets
        )
    }

    private var effectiveSelectedAssetName: String? {
        PlayerEnvironmentMenuPolicy.effectiveSelectedAssetName(
            appStateSelectedAsset: appState.selectedEnvironmentAsset,
            assets: assets
        )
    }
}
#endif
