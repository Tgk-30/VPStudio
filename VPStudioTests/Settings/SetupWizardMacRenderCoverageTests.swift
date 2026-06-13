import SwiftUI
import Testing
@testable import VPStudio

#if os(macOS)
import AppKit

@MainActor
@Suite("Setup Wizard macOS Render Coverage", .serialized)
struct SetupWizardMacRenderCoverageTests {
    @Test
    func hostsEverySetupStepWithSeededValues() {
        let appState = AppState(testHooks: .init())

        for step in 0..<5 {
            let size = host(
                SetupWizardView(
                    initialStep: step,
                    initialDebridApiKey: "fixture-debrid-key",
                    initialSelectedService: .realDebrid,
                    initialTMDBApiKey: "fixture-tmdb-key",
                    initialSelectedAIProvider: .openRouter,
                    initialAIAPIKey: "fixture-ai-key",
                    initialSelectedQuality: .uhd4k,
                    initialSelectedSubtitleLanguage: .english
                )
                .environment(appState)
                .frame(width: 760, height: 760)
            )

            #expect(size.width > 0, "Setup step \(step) should produce a hosted width")
            #expect(size.height > 0, "Setup step \(step) should produce a hosted height")
        }
    }

    @Test
    func hostsClampedBoundaryStepsWithEmptyOptionalValues() {
        let appState = AppState(testHooks: .init())
        let boundarySteps = [-3, 99]

        for requestedStep in boundarySteps {
            let size = host(
                SetupWizardView(
                    initialStep: requestedStep,
                    initialDebridApiKey: "",
                    initialSelectedService: .premiumize,
                    initialTMDBApiKey: "",
                    initialSelectedAIProvider: .none,
                    initialAIAPIKey: "",
                    initialSelectedQuality: .hd720p,
                    initialSelectedSubtitleLanguage: .none
                )
                .environment(appState)
                .frame(width: 720, height: 720)
            )

            #expect(size.width > 0, "Requested setup step \(requestedStep) should lay out after clamping")
            #expect(size.height > 0, "Requested setup step \(requestedStep) should lay out after clamping")
        }
    }

    private func host<Content: View>(_ view: Content) -> CGSize {
        let host = NSHostingView(rootView: AnyView(view))
        host.frame = CGRect(x: 0, y: 0, width: 760, height: 760)
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 760, height: 760),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        window.contentView = host
        window.makeKeyAndOrderFront(nil)
        host.layoutSubtreeIfNeeded()
        RunLoop.main.run(until: Date().addingTimeInterval(0.08))
        host.layoutSubtreeIfNeeded()
        let size = host.fittingSize
        window.orderOut(nil)
        Self.retainedWindows.append(window)
        if Self.retainedWindows.count > 8 {
            Self.retainedWindows.removeFirst(Self.retainedWindows.count - 8)
        }
        return size
    }

    private static var retainedWindows: [NSWindow] = []
}
#endif
