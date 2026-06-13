import SwiftUI
import Testing
@testable import VPStudio

@Suite("TextInputCompatibility Extension")
@MainActor
struct TextInputCompatibilityExtensionTests {

    @Test("disableAutomaticTextEntryAdjustments returns a modified view on macOS")
    func disableAutomaticTextEntryAdjustmentsExists() {
        struct TestView: View {
            @ViewBuilder
            var body: some View {
                Text("Test")
                    .disableAutomaticTextEntryAdjustments()
            }
        }
        SwiftUIViewDiagnosticHost.render(TestView())
    }

    @Test("disableAutomaticTextEntryAdjustments can be chained")
    func disableAutomaticTextEntryAdjustmentsChainable() {
        struct TestView: View {
            var body: some View {
                Text("Test")
                    .disableAutomaticTextEntryAdjustments()
                    .frame(width: 100)
            }
        }
        SwiftUIViewDiagnosticHost.render(TestView())
    }
}
