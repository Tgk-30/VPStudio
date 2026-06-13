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
                isActive: true,
                sourceType: .bundled
            ) == "checkmark"
        )
        #expect(
            PlayerEnvironmentMenuPolicy.menuAssetIconName(
                isActive: false,
                sourceType: .bundled
            ) == "circle.fill"
        )
        #expect(
            PlayerEnvironmentMenuPolicy.menuAssetIconName(
                isActive: false,
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
    func standardMenuAssetSpecPreservesBundledImportedAndActiveIcons() {
        let activeAsset = makeAsset(
            id: "active",
            name: "Active",
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

        #expect(PlayerEnvironmentMenuLabelSpec.menuAsset(activeAsset).leadingSystemImage == "checkmark")
        #expect(PlayerEnvironmentMenuLabelSpec.menuAsset(bundledAsset).leadingSystemImage == "circle.fill")
        #expect(PlayerEnvironmentMenuLabelSpec.menuAsset(importedAsset).leadingSystemImage == "pano")
    }

    @Test
    func compactMenuAssetSpecOnlyShowsSelectionCheckmarkForMatchingOpenAsset() {
        let selectedAsset = makeAsset(
            id: "selected",
            name: "Northern Sky",
            sourceType: .imported,
            assetPath: "northern-sky.hdr"
        )
        let selectedSpec = PlayerEnvironmentMenuLabelSpec.compactAsset(
            selectedAsset,
            selectedAssetID: "selected",
            isImmersiveSpaceOpen: true
        )
        let closedSpec = PlayerEnvironmentMenuLabelSpec.compactAsset(
            selectedAsset,
            selectedAssetID: "selected",
            isImmersiveSpaceOpen: false
        )
        let otherSpec = PlayerEnvironmentMenuLabelSpec.compactAsset(
            selectedAsset,
            selectedAssetID: "other",
            isImmersiveSpaceOpen: true
        )

        #expect(selectedSpec.leadingSystemImage == "pano")
        #expect(selectedSpec.trailingSystemImage == "checkmark")
        #expect(closedSpec.trailingSystemImage == nil)
        #expect(otherSpec.trailingSystemImage == nil)
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
                isImmersiveSpaceOpen: false
            ).leadingSystemImage == "cube.transparent"
        )
    }

    @Test
    func rowLabelBodiesRenderExpectedSymbolNames() {
        let plainSpec = PlayerEnvironmentMenuLabelSpec(
            title: "Cinema Environment",
            leadingSystemImage: "theatermasks",
            trailingSystemImage: nil
        )
        let trailingSpec = PlayerEnvironmentMenuLabelSpec(
            title: "Northern Sky",
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
        var dismissedCount = 0

        PlayerEnvironmentCinemaRow(
            spec: .cinema(activeEnvironment: nil, isImmersiveSpaceOpen: false),
            action: { selectedCinema = true }
        ).performAction()

        PlayerEnvironmentMenuAssetRow(
            asset: asset,
            action: { selectedAssetID = $0.id }
        ).performAction()

        PlayerEnvironmentCompactAssetRow(
            asset: asset,
            selectedAssetID: asset.id,
            isImmersiveSpaceOpen: true,
            action: { selectedAssetID = $0.id }
        ).performAction()

        PlayerEnvironmentExitRow(role: .destructive) {
            dismissedCount += 1
        }.performAction()

        #expect(selectedCinema)
        #expect(selectedAssetID == asset.id)
        #expect(dismissedCount == 1)
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
        SwiftUIViewDiagnosticHost.render(PlayerEnvironmentMenuAssetRow(asset: asset, action: { _ in }))
        SwiftUIViewDiagnosticHost.render(PlayerEnvironmentCompactAssetRow(
            asset: asset,
            selectedAssetID: asset.id,
            isImmersiveSpaceOpen: true,
            action: { _ in }
        ))
        SwiftUIViewDiagnosticHost.render(PlayerEnvironmentExitRow(role: nil, action: {}))

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
        #expect(source.contains("leadingSystemImage: PlayerEnvironmentMenuPolicy.cinemaIconName("))
        #expect(source.contains(#"leadingSystemImage: PlayerEnvironmentMenuPolicy.menuAssetIconName("#))
        #expect(source.contains(#"Label("Exit Environment", systemImage: "xmark.circle")"#))
        #expect(containsIgnoringWhitespace(source, #"Image(systemName: PlayerEnvironmentMenuPolicy.triggerIconName(isImmersiveSpaceOpen: appState.isImmersiveSpaceOpen))"#))
    }

    @Test
    func emptyStateCopyIsOnlyUsedByTheCompactButtonMenu() throws {
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
        #expect(buttonBody.contains("No environments available"))
        #expect(buttonBody.contains("if PlayerEnvironmentMenuPolicy.showsEmptyAssetMessage(assetCount: assets.count) {"))
        #expect(buttonBody.contains("Text(\"No environments available\")"))
        #expect(buttonBody.contains("} else {"))
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
        #expect(buttonBody.contains(".buttonStyle(.plain)"))
        #expect(buttonBody.contains(".hoverEffect(.lift)"))
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
        #expect(menuBody.contains("PlayerEnvironmentCinemaRow("))
        #expect(menuBody.contains("PlayerEnvironmentMenuAssetRow(asset: asset, action: onSelect)"))
        #expect(menuBody.contains("PlayerEnvironmentExitRow(role: nil, action: onDismiss)"))
        #expect(buttonBody.contains("PlayerEnvironmentCompactAssetRow("))
        #expect(buttonBody.contains("PlayerEnvironmentExitRow(role: .destructive, action: onDismiss)"))
        #expect(menuBody.contains("Image(systemName: PlayerEnvironmentMenuPolicy.triggerIconName(isImmersiveSpaceOpen: appState.isImmersiveSpaceOpen))"))
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
