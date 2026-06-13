import Testing
@testable import VPStudio

@Suite("DetailPlayerHandoffPolicy")
struct DetailPlayerHandoffPolicyTests {
    @Test
    func activeSessionAlwaysShowsToast() {
        #expect(
            DetailPlayerHandoffPolicy.route(
                hasActivePlayerSession: true,
                didLaunchPreferredExternalPlayer: false
            ) == .showActiveSessionToast
        )

        #expect(
            DetailPlayerHandoffPolicy.route(
                hasActivePlayerSession: true,
                didLaunchPreferredExternalPlayer: true
            ) == .showActiveSessionToast
        )
    }

    @Test
    func externalLaunchWinsWhenNoActiveSession() {
        #expect(
            DetailPlayerHandoffPolicy.route(
                hasActivePlayerSession: false,
                didLaunchPreferredExternalPlayer: true
            ) == .launchedExternally
        )
    }

    @Test
    func fallsBackToInternalPlayerWhenNoSessionAndNoExternalLaunch() {
        #expect(
            DetailPlayerHandoffPolicy.route(
                hasActivePlayerSession: false,
                didLaunchPreferredExternalPlayer: false
            ) == .openInternalPlayerWindow
        )
    }
}
