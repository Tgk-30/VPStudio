import SwiftUI
import Testing
@testable import VPStudio

@Suite("AsyncStateViews View Extension")
@MainActor
struct AsyncStateViewsExtensionTests {

    @Test("appErrorAlert returns modified view")
    func appErrorAlertExists() {
        struct TestView: View {
            @State private var error: AppError?
            var body: some View {
                Text("Test")
                    .appErrorAlert(error: $error)
            }
        }
        SwiftUIViewDiagnosticHost.render(TestView())
    }

    @Test("appErrorAlert accepts custom title")
    func appErrorAlertCustomTitle() {
        struct TestView: View {
            @State private var error: AppError?
            var body: some View {
                Text("Test")
                    .appErrorAlert("Custom Error", error: $error)
            }
        }
        SwiftUIViewDiagnosticHost.render(TestView())
    }

    @Test("appErrorAlert accepts retry callback")
    func appErrorAlertWithRetry() {
        struct TestView: View {
            @State private var error: AppError?
            var body: some View {
                Text("Test")
                    .appErrorAlert("Error", error: $error, onRetry: {
                        print("Retry")
                    })
            }
        }
        SwiftUIViewDiagnosticHost.render(TestView())
    }

    @Test("appErrorAlert with nil error is not presented")
    func appErrorAlertNilError() {
        struct TestView: View {
            @State private var error: AppError? = nil
            var body: some View {
                Text("Test")
                    .appErrorAlert(error: $error)
            }
        }
        SwiftUIViewDiagnosticHost.render(TestView())
    }
}
