import Foundation
import SwiftUI
import Testing
@testable import VPStudio

#if os(visionOS)
@Suite("Player Environment Menu Runtime Policy Contracts")
struct PlayerEnvironmentMenuRuntimePolicyTests {
    @Test
    func exitEnvironmentVisibilityTracksImmersiveState() {
        #expect(PlayerEnvironmentMenuPolicy.showsExitEnvironment(isImmersiveSpaceOpen: true))
        #expect(!PlayerEnvironmentMenuPolicy.showsExitEnvironment(isImmersiveSpaceOpen: false))
    }

    @Test
    func emptyAssetMessageOnlyAppearsWhenNoAssetsExist() {
        #expect(PlayerEnvironmentMenuPolicy.showsEmptyAssetMessage(assetCount: 0))
        #expect(!PlayerEnvironmentMenuPolicy.showsEmptyAssetMessage(assetCount: 1))
    }

    @Test
    func assetIconPolicyFallsBackPredictably() {
        #expect(
            PlayerEnvironmentMenuPolicy.menuAssetIconName(
                assetID: "selected",
                selectedAssetID: "selected",
                activeEnvironment: .customEnvironment,
                sourceType: .bundled
            ) == "checkmark"
        )
        #expect(
            PlayerEnvironmentMenuPolicy.menuAssetIconName(
                assetID: "bundled",
                selectedAssetID: "other",
                activeEnvironment: .customEnvironment,
                sourceType: .bundled
            ) == "circle.fill"
        )
        #expect(
            PlayerEnvironmentMenuPolicy.menuAssetIconName(
                assetID: "imported",
                selectedAssetID: nil,
                activeEnvironment: nil,
                sourceType: .imported
            ) == "pano"
        )
        #expect(PlayerEnvironmentMenuPolicy.compactAssetIconName(forAssetPath: "room.hdr") == "pano")
        #expect(PlayerEnvironmentMenuPolicy.compactAssetIconName(forAssetPath: "room.usdz") == "cube.transparent")
    }
}

@MainActor
@Suite("Player Environment Menu View Coverage")
struct PlayerEnvironmentMenuViewCoverageTests {
    @Test
    func cinemaLabelSpecKeepsTheaterMasksAndCheckmarkStates() {
        let activeSpec = PlayerEnvironmentMenuLabelSpec.cinema(
            activeEnvironment: .cinemaEnvironment,
            isImmersiveSpaceOpen: true
        )
        let inactiveSpec = PlayerEnvironmentMenuLabelSpec.cinema(
            activeEnvironment: .customEnvironment,
            isImmersiveSpaceOpen: true
        )

        #expect(activeSpec.title == "Cinema Environment")
        #expect(activeSpec.leadingSystemImage == "checkmark")
        #expect(activeSpec.trailingSystemImage == nil)
        #expect(inactiveSpec.leadingSystemImage == "theatermasks")
    }

    @Test
    func standardLabelSpecDoesNotPromiseReflectionsWithoutSystemVideoSurface() {
        let avPlayerSpec = PlayerEnvironmentMenuLabelSpec.standardRoom(
            selectedAssetID: "env",
            activeEnvironment: nil,
            isImmersiveSpaceOpen: false,
            canUseSystemVideoSurface: true
        )
        let fallbackSpec = PlayerEnvironmentMenuLabelSpec.standardRoom(
            selectedAssetID: "env",
            activeEnvironment: nil,
            isImmersiveSpaceOpen: false,
            canUseSystemVideoSurface: false
        )

        #expect(avPlayerSpec.subtitle == PlayerEnvironmentMenuPolicy.appleEnvironmentMenuBenefit)
        #expect(avPlayerSpec.subtitle?.localizedCaseInsensitiveContains("reflections") == false)
        #expect(fallbackSpec.subtitle == PlayerEnvironmentMenuPolicy.appleEnvironmentFallbackBenefit)
        #expect(fallbackSpec.subtitle?.localizedCaseInsensitiveContains("reflections") == false)
        #expect(fallbackSpec.menuTitle == "Apple Environment - Standard window until supported playback is active")
    }

    @Test
    func standardMenuAssetSpecUsesLiveSelectionInsteadOfPersistedAssetFlags() {
        let selectedAsset = makeAsset(
            id: "selected",
            name: "Selected",
            sourceType: .bundled,
            assetPath: "room.usdz",
            isActive: true
        )
        let bundledAsset = makeAsset(
            id: "bundled",
            name: "Bundled",
            sourceType: .bundled,
            assetPath: "room.usdz"
        )
        let importedAsset = makeAsset(
            id: "imported",
            name: "Imported",
            sourceType: .imported,
            assetPath: "room.hdr"
        )

        #expect(PlayerEnvironmentMenuLabelSpec.menuAsset(
            selectedAsset,
            selectedAssetID: "selected",
            activeEnvironment: .customEnvironment,
            isImmersiveSpaceOpen: true
        ).leadingSystemImage == "checkmark")
        #expect(PlayerEnvironmentMenuLabelSpec.menuAsset(
            bundledAsset,
            selectedAssetID: "selected",
            activeEnvironment: .customEnvironment,
            isImmersiveSpaceOpen: true
        ).leadingSystemImage == "circle.fill")
        #expect(PlayerEnvironmentMenuLabelSpec.menuAsset(
            importedAsset,
            selectedAssetID: nil,
            activeEnvironment: nil,
            isImmersiveSpaceOpen: false
        ).leadingSystemImage == "pano")
        #expect(PlayerEnvironmentMenuLabelSpec.menuAsset(
            selectedAsset,
            selectedAssetID: "selected",
            activeEnvironment: .cinemaEnvironment,
            isImmersiveSpaceOpen: true
        ).leadingSystemImage == "circle.fill")
        #expect(PlayerEnvironmentMenuLabelSpec.menuAsset(
            selectedAsset,
            selectedAssetID: "selected",
            activeEnvironment: .customEnvironment,
            isImmersiveSpaceOpen: true
        ).subtitle == "Active now")
    }

    @Test
    func compactMenuAssetSpecShowsSelectionCheckmarkForMatchingSelectedAsset() {
        let selectedAsset = makeAsset(
            id: "selected",
            name: "Northern Sky",
            sourceType: .imported,
            assetPath: "northern-sky.hdr"
        )
        let selectedSpec = PlayerEnvironmentMenuLabelSpec.compactAsset(
            selectedAsset,
            selectedAssetID: "selected",
            activeEnvironment: .customEnvironment,
            isImmersiveSpaceOpen: true
        )
        let closedSpec = PlayerEnvironmentMenuLabelSpec.compactAsset(
            selectedAsset,
            selectedAssetID: "selected",
            activeEnvironment: .customEnvironment,
            isImmersiveSpaceOpen: false
        )
        let otherSpec = PlayerEnvironmentMenuLabelSpec.compactAsset(
            selectedAsset,
            selectedAssetID: "other",
            activeEnvironment: .customEnvironment,
            isImmersiveSpaceOpen: true
        )
        let cinemaSpec = PlayerEnvironmentMenuLabelSpec.compactAsset(
            selectedAsset,
            selectedAssetID: "selected",
            activeEnvironment: .cinemaEnvironment,
            isImmersiveSpaceOpen: true
        )

        #expect(selectedSpec.leadingSystemImage == "pano")
        #expect(selectedSpec.trailingSystemImage == "checkmark")
        #expect(closedSpec.trailingSystemImage == "checkmark")
        #expect(otherSpec.trailingSystemImage == nil)
        // The trailing checkmark tracks the persistent selection, so it stays for
        // the selected asset even while Cinema is the active environment (see
        // playerEnvironmentMenuKeepsAssetSelectionVisibleWhileCinemaIsActive).
        #expect(cinemaSpec.trailingSystemImage == "checkmark")
    }

    @Test
    func compactMenuAssetSpecUsesModelIconForUSDZAssets() {
        let asset = makeAsset(
            id: "model",
            name: "Studio",
            sourceType: .bundled,
            assetPath: "studio.usdz"
        )

        #expect(
            PlayerEnvironmentMenuLabelSpec.compactAsset(
                asset,
                selectedAssetID: nil,
                activeEnvironment: nil,
                isImmersiveSpaceOpen: false
            ).leadingSystemImage == "cube.transparent"
        )
    }

    @Test
    func rowLabelBodiesRenderExpectedSymbolNames() {
        let plainSpec = PlayerEnvironmentMenuLabelSpec(
            title: "Cinema Environment",
            subtitle: nil,
            leadingSystemImage: "theatermasks",
            trailingSystemImage: nil
        )
        let trailingSpec = PlayerEnvironmentMenuLabelSpec(
            title: "Northern Sky",
            subtitle: "Active now",
            leadingSystemImage: "pano",
            trailingSystemImage: "checkmark"
        )

        _ = PlayerEnvironmentMenuLabel(spec: plainSpec).body
        _ = PlayerEnvironmentMenuLabel(spec: trailingSpec).body

        #expect(plainSpec.leadingSystemImage == "theatermasks")
        #expect(plainSpec.trailingSystemImage == nil)
        #expect(trailingSpec.leadingSystemImage == "pano")
        #expect(trailingSpec.trailingSystemImage == "checkmark")
    }

    @Test
    func rowActionsForwardSelectionAndDismissal() {
        let asset = makeAsset(
            id: "selected",
            name: "Northern Sky",
            sourceType: .imported,
            assetPath: "northern-sky.hdr"
        )
        var selectedCinema = false
        var selectedAssetID: String?
        var clearedStandardRoom = false
        var expandedAppleEnvironment = false
        var dismissedCount = 0

        PlayerEnvironmentCinemaRow(
            spec: .cinema(activeEnvironment: nil, isImmersiveSpaceOpen: false),
            action: { selectedCinema = true }
        ).performAction()

        PlayerEnvironmentStandardRow(
            spec: .standardRoom(
                selectedAssetID: selectedAssetID,
                activeEnvironment: nil,
                isImmersiveSpaceOpen: false
            ),
            action: { clearedStandardRoom = true }
        ).performAction()

        PlayerEnvironmentMenuAssetRow(
            asset: asset,
            selectedAssetID: selectedAssetID,
            activeEnvironment: nil,
            isImmersiveSpaceOpen: false,
            action: { selectedAssetID = $0.id }
        ).performAction()

        PlayerEnvironmentCompactAssetRow(
            asset: asset,
            selectedAssetID: asset.id,
            activeEnvironment: .customEnvironment,
            isImmersiveSpaceOpen: true,
            action: { selectedAssetID = $0.id }
        ).performAction()

        PlayerEnvironmentAppleExpandRow {
            expandedAppleEnvironment = true
        }.performAction()

        PlayerEnvironmentExitRow(role: nil) {
            dismissedCount += 1
        }.performAction()

        var closedMenu = false
        PlayerEnvironmentCloseMenuRow {
            closedMenu = true
        }.performAction()

        #expect(selectedCinema)
        #expect(clearedStandardRoom)
        #expect(selectedAssetID == asset.id)
        #expect(expandedAppleEnvironment)
        #expect(dismissedCount == 1)
        #expect(closedMenu)
    }

    @Test
    func extractedRowsBuildSwiftUIBodies() {
        let asset = makeAsset(
            id: "selected",
            name: "Northern Sky",
            sourceType: .imported,
            assetPath: "northern-sky.hdr"
        )

        SwiftUIViewDiagnosticHost.render(PlayerEnvironmentCinemaRow(
            spec: .cinema(activeEnvironment: .cinemaEnvironment, isImmersiveSpaceOpen: true),
            action: {}
        ))
        SwiftUIViewDiagnosticHost.render(PlayerEnvironmentStandardRow(
            spec: .standardRoom(
                selectedAssetID: nil,
                activeEnvironment: nil,
                isImmersiveSpaceOpen: false
            ),
            action: {}
        ))
        SwiftUIViewDiagnosticHost.render(PlayerEnvironmentMenuAssetRow(
            asset: asset,
            selectedAssetID: nil,
            activeEnvironment: nil,
            isImmersiveSpaceOpen: false,
            action: { _ in }
        ))
        SwiftUIViewDiagnosticHost.render(PlayerEnvironmentCompactAssetRow(
            asset: asset,
            selectedAssetID: asset.id,
            activeEnvironment: .customEnvironment,
            isImmersiveSpaceOpen: true,
            action: { _ in }
        ))
        SwiftUIViewDiagnosticHost.render(PlayerEnvironmentAppleExpandRow(action: {}))
        SwiftUIViewDiagnosticHost.render(PlayerEnvironmentExitRow(role: nil, action: {}))
        SwiftUIViewDiagnosticHost.render(PlayerEnvironmentCloseMenuRow(action: {}))

        #expect(asset.name == "Northern Sky")
    }

    private func makeAsset(
        id: String,
        name: String,
        sourceType: EnvironmentAssetSourceType,
        assetPath: String,
        isActive: Bool = false
    ) -> EnvironmentAsset {
        EnvironmentAsset(
            id: id,
            name: name,
            sourceType: sourceType,
            assetPath: assetPath,
            createdAt: Date(timeIntervalSince1970: 1),
            isActive: isActive
        )
    }
}
#endif

@Suite("Player Environment Menu Source Contracts")
struct PlayerEnvironmentMenuSourceContractTests {
    @Test
    func menuLabelsAndIconsStayStable() throws {
        let source = try Self.playerEnvironmentMenuSource()

        #expect(source.contains(#"title: "Cinema Environment""#))
        #expect(source.contains("title: EnvironmentPreviewRowPolicy.appleEnvironmentTitle"))
        #expect(source.contains("PlayerEnvironmentMenuPolicy.triggerTitle("))
        #expect(source.contains("leadingSystemImage: PlayerEnvironmentMenuPolicy.standardRoomIconName("))
        #expect(source.contains("leadingSystemImage: PlayerEnvironmentMenuPolicy.cinemaIconName("))
        #expect(source.contains("canOpenCinema: canOpenCinema"))
        #expect(source.contains("canUseSystemVideoSurface: canUseSystemVideoSurface"))
        #expect(source.contains("static let appleEnvironmentFallbackBenefit"))
        #expect(source.contains("static let appleEnvironmentPendingBenefit"))
        #expect(source.contains("static let appleEnvironmentExpandTitle"))
        #expect(source.contains("static let closeMenuTitle = PlayerCinematicChromePolicy.closeMenuTitle"))
        #expect(source.contains("var onCloseMenu: () -> Void = {}"))
        #expect(source.contains("PlayerEnvironmentCloseMenuRow(action: onCloseMenu)"))
        #expect(source.contains("static let appleEnvironmentExpandIconName"))
        #expect(source.contains("PlayerEnvironmentAppleExpandRow"))
        #expect(source.contains("PlayerEnvironmentMenuPolicy.showsAppleEnvironmentExpandAction("))
        #expect(source.contains("PlayerEnvironmentMenuPolicy.appleEnvironmentExpandTitle"))
        #expect(source.contains("PlayerEnvironmentMenuPolicy.appleEnvironmentExpandIconName"))
        #expect(source.contains("System expansion with reflections") == false)
        #expect(source.contains("Standard window; needs AVPlayer surface") == false)
        #expect(source.contains("System Scene") == false)
        #expect(source.contains("Requires AVPlayer playback") == false)
        #expect(source.contains("PlayerCinemaEnvironmentPolicy.unavailableMessage"))
        #expect(source.contains(#"leadingSystemImage: PlayerEnvironmentMenuPolicy.menuAssetIconName("#))
        #expect(source.contains("asset.isActive") == false)
        #expect(source.contains("let selectedAssetID = effectiveSelectedAssetID"))
        #expect(source.contains("private var effectiveSelectedAssetID"))
        #expect(source.contains("private var effectiveSelectedAssetName"))
        #expect(source.contains("activeEnvironment: appState.activeEnvironment"))
        #expect(source.contains(#"Label("Exit Environment", systemImage: "xmark.circle")"#))
        #expect(containsIgnoringWhitespace(
            source,
            """
            Image(systemName: PlayerEnvironmentMenuPolicy.triggerIconName(
                selectedAssetID: selectedAssetID,
                activeEnvironment: appState.activeEnvironment,
                isImmersiveSpaceOpen: appState.isImmersiveSpaceOpen
            ))
            """
        ))
        #expect(source.contains(".accessibilityLabel(PlayerEnvironmentMenuPolicy.triggerTitle("))
        #expect(source.contains(".blue") == false)
        #expect(source.contains("VPColor.info"))
    }

    @Test
    func emptyImportedStateKeepsBundledEnvironmentRowsVisible() throws {
        let source = try Self.playerEnvironmentMenuSource()
        let menuBody = try section(
            from: "struct PlayerEnvironmentMenu: View {",
            to: "struct PlayerEnvironmentButton: View {",
            in: source
        )
        let buttonBody = try section(
            from: "struct PlayerEnvironmentButton: View {",
            to: "}\n#endif",
            in: source
        )

        #expect(!menuBody.contains("No environments available"))
        #expect(buttonBody.contains("No imported environments"))
        #expect(buttonBody.contains("if PlayerEnvironmentMenuPolicy.showsEmptyImportedAssetMessage(assets: assets) {"))
        #expect(buttonBody.contains("Text(\"No imported environments\")"))
        #expect(buttonBody.contains("ForEach(assets, id: \\.id)"))
    }

    @Test
    func exitEnvironmentAndTriggerBehaviorStayUnnestedAndLightweight() throws {
        let source = try Self.playerEnvironmentMenuSource()
        let menuBody = try section(
            from: "struct PlayerEnvironmentMenu: View {",
            to: "struct PlayerEnvironmentButton: View {",
            in: source
        )
        let buttonBody = try section(
            from: "struct PlayerEnvironmentButton: View {",
            to: "}\n#endif",
            in: source
        )

        #expect(countOccurrences(of: "Menu {", in: menuBody) == 1)
        #expect(countOccurrences(of: "Menu {", in: buttonBody) == 1)
        #expect(menuBody.contains("showsExitEnvironment(isImmersiveSpaceOpen: appState.isImmersiveSpaceOpen)"))
        #expect(buttonBody.contains("showsExitEnvironment(isImmersiveSpaceOpen: appState.isImmersiveSpaceOpen)"))
        #expect(menuBody.contains("PlayerEnvironmentAppleExpandRow(action: onExpandAppleEnvironment)"))
        #expect(buttonBody.contains("PlayerEnvironmentAppleExpandRow(action: onExpandAppleEnvironment)"))
        #expect(buttonBody.contains(".buttonStyle(.plain)"))
        #expect(buttonBody.contains(".hoverEffect(.lift)"))
        #expect(source.contains("static let triggerDisclosureIconName = \"chevron.down\""))
        #expect(source.contains("static let compactTriggerMinWidth: CGFloat = 170"))
        #expect(source.contains("static let compactTriggerMaxWidth: CGFloat = 328"))
        #expect(source.contains("static let compactTriggerMinHeight: CGFloat = PlayerCinematicChromePolicy.quickActionPillMinHeight"))
        #expect(source.contains("static let compactTriggerMinimumScaleFactor: CGFloat = 0.88"))
        #expect(source.contains("static let menuRowMinimumScaleFactor: CGFloat = 0.78"))
        #expect(source.contains("Image(systemName: PlayerEnvironmentMenuPolicy.triggerDisclosureIconName)"))
        #expect(source.contains(".minimumScaleFactor(PlayerEnvironmentMenuPolicy.menuRowMinimumScaleFactor)"))
        #expect(source.contains(".minimumScaleFactor(PlayerEnvironmentMenuPolicy.compactTriggerMinimumScaleFactor)"))
        #expect(source.contains(".layoutPriority(1)"))
        #expect(source.contains(".fixedSize()"))
        #expect(source.contains("minWidth: PlayerEnvironmentMenuPolicy.compactTriggerMinWidth"))
        #expect(source.contains("maxWidth: PlayerEnvironmentMenuPolicy.compactTriggerMaxWidth"))
        #expect(source.contains("minHeight: PlayerEnvironmentMenuPolicy.compactTriggerMinHeight"))
        #expect(source.contains(".contentShape(Capsule())"))
        #expect(containsIgnoringWhitespace(
            source,
            """
            /// Isolated subview for the environment picker in the player transport controls.
            ///
            /// By separating this into its own View struct, SwiftUI gives it an independent
            /// observation scope. It only re-evaluates when `AppState.isImmersiveSpaceOpen`
            /// or `assets` change — not on every engine time-tick that rebuilds the parent.
            """
        ))
        #expect(containsIgnoringWhitespace(
            source,
            """
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
            """
        ))
    }

    @Test
    func menuUsesTheExpectedBranchStructure() throws {
        let source = try Self.playerEnvironmentMenuSource()
        let menuBody = try section(
            from: "struct PlayerEnvironmentMenu: View {",
            to: "struct PlayerEnvironmentButton: View {",
            in: source
        )
        let buttonBody = try section(
            from: "struct PlayerEnvironmentButton: View {",
            to: "}\n#endif",
            in: source
        )

        #expect(menuBody.contains("Divider()"))
        #expect(menuBody.contains("ForEach(assets, id: \\.id) { asset in"))
        #expect(menuBody.contains("PlayerEnvironmentStandardRow("))
        #expect(menuBody.contains("PlayerEnvironmentCinemaRow("))
        #expect(menuBody.contains("PlayerEnvironmentMenuAssetRow("))
        #expect(menuBody.contains("let selectedAssetID = effectiveSelectedAssetID"))
        #expect(menuBody.contains("activeEnvironment: appState.activeEnvironment"))
        #expect(menuBody.contains("isImmersiveSpaceOpen: appState.isImmersiveSpaceOpen"))
        #expect(menuBody.contains("PlayerEnvironmentExitRow(role: nil, action: onDismiss)"))
        #expect(buttonBody.contains("PlayerEnvironmentStandardRow("))
        #expect(buttonBody.contains("PlayerEnvironmentCompactAssetRow("))
        #expect(buttonBody.contains("PlayerEnvironmentExitRow(role: nil, action: onDismiss)"))
        #expect(menuBody.contains("PlayerEnvironmentMenuPolicy.triggerIconName("))
        #expect(menuBody.contains("selectedAssetID: selectedAssetID"))
        #expect(menuBody.contains("private var effectiveSelectedAssetName"))
    }

    private static func playerEnvironmentMenuSource() throws -> String {
        try contents(of: "VPStudio/Views/Windows/Player/PlayerEnvironmentMenu.swift")
    }
}

private func containsIgnoringWhitespace(_ source: String, _ snippet: String) -> Bool {
    normalizedWhitespace(source).contains(normalizedWhitespace(snippet))
}

private func normalizedWhitespace(_ source: String) -> String {
    source
        .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
        .trimmingCharacters(in: .whitespacesAndNewlines)
}

private func countOccurrences(of token: String, in source: String) -> Int {
    source.components(separatedBy: token).count - 1
}

private func section(from start: String, to end: String, in source: String) throws -> String {
    guard let startRange = source.range(of: start) else {
        throw NSError(
            domain: "PlayerEnvironmentMenuContractTests",
            code: 1,
            userInfo: [NSLocalizedDescriptionKey: "Missing start token: \(start)"]
        )
    }
    guard let endRange = source.range(of: end, range: startRange.upperBound..<source.endIndex) else {
        throw NSError(
            domain: "PlayerEnvironmentMenuContractTests",
            code: 2,
            userInfo: [NSLocalizedDescriptionKey: "Missing end token: \(end)"]
        )
    }
    return String(source[startRange.lowerBound..<endRange.lowerBound])
}

private func contents(of relativePath: String) throws -> String {
    let absolutePath = repoRootURL().appendingPathComponent(relativePath).path
    return try String(contentsOfFile: absolutePath, encoding: .utf8)
}

private func repoRootURL() -> URL {
    var url = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
    while !FileManager.default.fileExists(atPath: url.appendingPathComponent("Package.swift").path) {
        let parent = url.deletingLastPathComponent()
        if parent.path == url.path { break }
        url = parent
    }
    return url
}
