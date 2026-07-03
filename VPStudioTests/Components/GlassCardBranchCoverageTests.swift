import SwiftUI
import Testing
@testable import VPStudio

#if os(macOS)
import AppKit
#endif

@MainActor
@Suite("GlassCard Branch Coverage")
struct GlassCardBranchCoverageTests {
    @Test
    func flowLayoutStoresCustomSpacing() {
        #expect(FlowLayout().spacing == 6)
        #expect(FlowLayout(spacing: 11).spacing == 11)
    }

    @Test
    func glassViewModifiersBuildWithCustomParameters() {
        _ = Text("Stroke").glassStroke(cornerRadius: 8, lineWidth: 0.5)
        _ = Text("Shadow").glassShadow()
        _ = Text("Card").glassCard(cornerRadius: 10, material: .regularMaterial)
    }

    @Test
    func artworkFallbackStyleHandlesFilteredAndFallbackInitials() {
        #expect(ArtworkFallbackStyle.initials(for: "The") == "TH")
        #expect(ArtworkFallbackStyle.initials(for: "!!!") == "VP")
        #expect(ArtworkFallbackStyle.initials(for: "a hidden gem") == "HG")
        #expect(ArtworkFallbackStyle.initials(for: "7") == "7")
    }

    @Test
    func artworkFallbackStyleHandlesNilTypeBranches() {
        #expect(ArtworkFallbackStyle.metadata(for: nil, year: 1995) == "FEATURE • 1995")
        #expect(ArtworkFallbackStyle.accentSymbol(for: nil) == "film.stack.fill")
        #expect(ArtworkFallbackStyle.palette(for: "Untyped Feature", type: nil).count == 2)
    }

    @Test
    func glassControlsBuildUntintedAndAccessibilityVariants() {
        var tapCount = 0

        _ = GlassTag(text: "Plain").body
        _ = SpatialButton(title: "Queue", icon: "text.badge.plus") {
            tapCount += 1
        }.body
        _ = GlassIconButton(
            icon: "info.circle",
            tint: nil,
            size: 32,
            accessibilityLabel: nil,
            accessibilityHint: "Shows details"
        ) {
            tapCount += 1
        }.body
        _ = GlassIconButton(icon: "play.fill") {
            tapCount += 1
        }.body
        _ = GlassProgressBar(progress: -0.25, tint: .red, height: 4).body
        _ = GlassProgressBar(progress: 0.5, tint: .green, height: 10).body
        _ = PasteFieldButton { _ in
            tapCount += 1
        }.body

        #expect(tapCount == 0)
    }

    #if os(macOS)
    @Test
    func flowLayoutWrapsRowsWhenHostedInConstrainedWidth() {
        let view = FlowLayout(spacing: 8) {
            Color.clear.frame(width: 80, height: 20)
            Color.clear.frame(width: 80, height: 20)
            Color.clear.frame(width: 80, height: 20)
        }
        .frame(width: 90, alignment: .leading)

        let host = NSHostingView(rootView: view)
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 90, height: 140),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        window.contentView = host
        host.layoutSubtreeIfNeeded()
        RunLoop.main.run(until: Date().addingTimeInterval(0.05))

        #expect(host.fittingSize.height > 40)
    }

    @Test
    func glassControlsHostOptionalBranches() {
        var tapCount = 0
        let view = VStack(spacing: 12) {
            FlowLayout(spacing: 4) {}
            GlassTag(text: "No Symbol")
            SpatialButton(title: "Default", icon: "play.circle") {
                tapCount += 1
            }
            GlassIconButton(
                icon: "questionmark.circle",
                accessibilityHint: "Explains the setting"
            ) {
                tapCount += 1
            }
            GlassIconButton(icon: "xmark") {
                tapCount += 1
            }
            GlassProgressBar(progress: 1.4)
            PasteFieldButton { _ in
                tapCount += 1
            }
        }
        .frame(width: 220, height: 260)

        let host = NSHostingView(rootView: view)
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 220, height: 260),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        window.contentView = host
        host.layoutSubtreeIfNeeded()
        RunLoop.main.run(until: Date().addingTimeInterval(0.05))

        #expect(host.fittingSize.width > 0)
        #expect(tapCount == 0)
    }
    #endif
}
