import Testing
@testable import VPStudio

struct PlayerEngineProtocolTests {

    // MARK: - PlayerEngineKind

    @Test
    func test_playerEngineKind_displayName() {
        #expect(PlayerEngineKind.ksPlayer.displayName == "KSPlayer")
        #expect(PlayerEngineKind.avPlayer.displayName == "AVPlayer")
    }

    @Test
    func test_playerEngineKind_caseIterable() {
        let allCases = PlayerEngineKind.allCases
        #expect(allCases.count == 2)
        #expect(allCases.contains(.ksPlayer))
        #expect(allCases.contains(.avPlayer))
    }

    // MARK: - PlayerPlaybackState

    @Test
    func test_playerPlaybackState_rawValue() {
        #expect(PlayerPlaybackState.preparing.rawValue == "preparing")
        #expect(PlayerPlaybackState.buffering.rawValue == "buffering")
        #expect(PlayerPlaybackState.playing.rawValue == "playing")
        #expect(PlayerPlaybackState.failed.rawValue == "failed")
    }

    // MARK: - PlayerEngineError

    @Test
    func test_playerEngineError_invalidStreamURL() {
        let error = PlayerEngineError.invalidStreamURL("invalid-url")
        #expect(error.errorDescription == "Invalid stream URL: invalid-url")
    }

    @Test
    func test_playerEngineError_startupTimeout() {
        let error = PlayerEngineError.startupTimeout(.avPlayer)
        #expect(error.errorDescription == "AVPlayer timed out before playback started.")

        let ksError = PlayerEngineError.startupTimeout(.ksPlayer)
        #expect(ksError.errorDescription == "KSPlayer timed out before playback started.")
    }

    @Test
    func test_playerEngineError_initializationFailed() {
        let error = PlayerEngineError.initializationFailed(.ksPlayer, "codec error")
        #expect(error.errorDescription == "KSPlayer failed: codec error")

        let avError = PlayerEngineError.initializationFailed(.avPlayer, "timeout")
        #expect(avError.errorDescription == "AVPlayer failed: timeout")
    }

    @Test
    func test_playerEngineError_equatable() {
        let error1 = PlayerEngineError.invalidStreamURL("test")
        let error2 = PlayerEngineError.invalidStreamURL("test")
        let error3 = PlayerEngineError.invalidStreamURL("other")

        #expect(error1 == error2)
        #expect(error1 != error3)
    }
}
