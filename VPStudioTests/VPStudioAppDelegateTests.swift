#if os(macOS)
import Foundation
import Testing
@testable import VPStudio

@Suite("VPStudio App Delegate")
struct VPStudioAppDelegateTests {
    @Test
    func appDelegateDoesNotTerminateAfterLastWindowCloses() throws {
        let source = try String(
            contentsOf: Self.appSourceURL(),
            encoding: .utf8
        )

        #expect(source.contains("final class VPStudioAppDelegate"))
        #expect(source.contains("applicationShouldTerminateAfterLastWindowClosed"))
        #expect(source.contains("false"))
    }

    private static func appSourceURL() -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .appendingPathComponent("../VPStudio/App/VPStudioApp.swift")
            .standardizedFileURL
    }
}
#endif
