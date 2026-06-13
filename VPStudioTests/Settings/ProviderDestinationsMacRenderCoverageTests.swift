import SwiftUI
import Testing
@testable import VPStudio

#if os(macOS)
import AppKit

@MainActor
@Suite("Provider Destination macOS Render Coverage", .serialized)
struct ProviderDestinationsMacRenderCoverageTests {
    @Test
    func debridSettingsHostsEmptyErrorAndAddSheetStatesOnMacOS() {
        let appState = AppState(testHooks: .init())
        let variants: [(String, DebridSettingsView)] = [
            ("Empty error", DebridSettingsView(
                initialSurfaceError: .unknown("Streaming provider settings failed to load in construction test."),
                disablesAutomaticTasks: true
            )),
            ("Add sheet", DebridSettingsView(
                initialShowingAddSheet: true,
                initialNewServiceType: .realDebrid,
                initialNewApiKey: "fixture-debrid-key",
                disablesAutomaticTasks: true
            )),
        ]

        for (name, view) in variants {
            let size = host(
                NavigationStack { view }
                    .environment(appState)
                    .frame(width: 760, height: 860),
                width: 760,
                height: 860
            )
            #expect(size.width > 0, "\(name) should produce a hosted width")
            #expect(size.height > 0, "\(name) should produce a hosted height")
        }
    }

    @Test
    func indexerSettingsHostsEmptyWarningAndEditorValidationStatesOnMacOS() {
        let appState = AppState(testHooks: .init())
        var invalidDraft = IndexerSettingsView.IndexerDraft.new()
        invalidDraft.name = "Fixture Torznab"
        invalidDraft.indexerType = .torznab
        invalidDraft.baseURL = "http://insecure.example"
        invalidDraft.apiKey = ""
        invalidDraft.endpointPath = "torznab/api"

        let variants: [(String, IndexerSettingsView)] = [
            ("Empty warning", IndexerSettingsView(
                initialNotice: .warning("No indexer responses are available in construction test."),
                disablesAutomaticTasks: true
            )),
            ("Editor validation", IndexerSettingsView(
                initialIsShowingEditor: true,
                initialDraft: invalidDraft,
                initialSurfaceError: .unknown("Indexer connection failed in construction test."),
                disablesAutomaticTasks: true
            )),
        ]

        for (name, view) in variants {
            let size = host(
                NavigationStack { view }
                    .environment(appState)
                    .frame(width: 760, height: 900),
                width: 760,
                height: 900
            )
            #expect(size.width > 0, "\(name) should produce a hosted width")
            #expect(size.height > 0, "\(name) should produce a hosted height")
        }
    }

    private func host<Content: View>(
        _ view: Content,
        width: CGFloat,
        height: CGFloat
    ) -> CGSize {
        let host = NSHostingView(rootView: AnyView(view))
        host.frame = CGRect(x: 0, y: 0, width: width, height: height)
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: width, height: height),
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
