import Testing
import Foundation
@testable import VPStudio

@Suite("PlayerLoadingPhase Extension")
struct PlayerLoadingPhaseExtensionTests {

    @Test("validNextPhases from connecting")
    func validNextPhasesFromConnecting() {
        let phases = PlayerLoadingPhase.connecting.validNextPhases
        #expect(phases.contains(.buffering))
        #expect(phases.contains(.preparingVideo))
        #expect(phases.contains(.switchingEngine))
        #expect(phases.contains(.retryingStream))
        #expect(phases.contains(.failed))
        #expect(phases.count == 5)
    }

    @Test("validNextPhases from buffering")
    func validNextPhasesFromBuffering() {
        let phases = PlayerLoadingPhase.buffering.validNextPhases
        #expect(phases.contains(.preparingVideo))
        #expect(phases.contains(.switchingEngine))
        #expect(phases.contains(.retryingStream))
        #expect(phases.contains(.ready))
        #expect(phases.contains(.failed))
        #expect(phases.count == 5)
    }

    @Test("validNextPhases from preparingVideo")
    func validNextPhasesFromPreparingVideo() {
        let phases = PlayerLoadingPhase.preparingVideo.validNextPhases
        #expect(phases.contains(.ready))
        #expect(phases.contains(.switchingEngine))
        #expect(phases.contains(.failed))
        #expect(phases.count == 3)
    }

    @Test("validNextPhases from switchingEngine")
    func validNextPhasesFromSwitchingEngine() {
        let phases = PlayerLoadingPhase.switchingEngine.validNextPhases
        #expect(phases.contains(.connecting))
        #expect(phases.contains(.buffering))
        #expect(phases.contains(.preparingVideo))
        #expect(phases.contains(.retryingStream))
        #expect(phases.contains(.ready))
        #expect(phases.contains(.failed))
        #expect(phases.count == 6)
    }

    @Test("validNextPhases from retryingStream")
    func validNextPhasesFromRetryingStream() {
        let phases = PlayerLoadingPhase.retryingStream.validNextPhases
        #expect(phases.contains(.connecting))
        #expect(phases.contains(.buffering))
        #expect(phases.contains(.preparingVideo))
        #expect(phases.contains(.switchingEngine))
        #expect(phases.contains(.ready))
        #expect(phases.contains(.failed))
        #expect(phases.count == 6)
    }

    @Test("validNextPhases from ready is empty")
    func validNextPhasesFromReady() {
        let phases = PlayerLoadingPhase.ready.validNextPhases
        #expect(phases.isEmpty)
    }

    @Test("validNextPhases from failed can return to connecting")
    func validNextPhasesFromFailed() {
        let phases = PlayerLoadingPhase.failed("test").validNextPhases
        #expect(phases.contains(.connecting))
        #expect(phases.count == 1)
    }

    @Test("kind maps connecting")
    func kindMapsConnecting() {
        #expect(PlayerLoadingPhase.connecting.kind == .connecting)
    }

    @Test("kind maps buffering")
    func kindMapsBuffering() {
        #expect(PlayerLoadingPhase.buffering.kind == .buffering)
    }

    @Test("kind maps preparingVideo")
    func kindMapsPreparingVideo() {
        #expect(PlayerLoadingPhase.preparingVideo.kind == .preparingVideo)
    }

    @Test("kind maps switchingEngine")
    func kindMapsSwitchingEngine() {
        #expect(PlayerLoadingPhase.switchingEngine.kind == .switchingEngine)
    }

    @Test("kind maps retryingStream")
    func kindMapsRetryingStream() {
        #expect(PlayerLoadingPhase.retryingStream.kind == .retryingStream)
    }

    @Test("kind maps ready")
    func kindMapsReady() {
        #expect(PlayerLoadingPhase.ready.kind == .ready)
    }

    @Test("kind maps failed")
    func kindMapsFailed() {
        #expect(PlayerLoadingPhase.failed("error").kind == .failed)
    }
}

@Suite("PlayerLoadingPhase Status Messages")
struct PlayerLoadingPhaseStatusMessageTests {

    @Test("connecting status message")
    func connectingStatusMessage() {
        #expect(PlayerLoadingPhase.connecting.statusMessage == "Connecting to stream\u{2026}")
    }

    @Test("buffering status message")
    func bufferingStatusMessage() {
        #expect(PlayerLoadingPhase.buffering.statusMessage == "Buffering video data\u{2026}")
    }

    @Test("preparingVideo status message")
    func preparingVideoStatusMessage() {
        #expect(PlayerLoadingPhase.preparingVideo.statusMessage == "Preparing video\u{2026}")
    }

    @Test("switchingEngine status message")
    func switchingEngineStatusMessage() {
        #expect(PlayerLoadingPhase.switchingEngine.statusMessage == "Switching to alternate player engine\u{2026}")
    }

    @Test("retryingStream status message")
    func retryingStreamStatusMessage() {
        #expect(PlayerLoadingPhase.retryingStream.statusMessage == "Trying next stream\u{2026}")
    }

    @Test("ready status message")
    func readyStatusMessage() {
        #expect(PlayerLoadingPhase.ready.statusMessage == "Starting playback")
    }

    @Test("failed status message with content")
    func failedStatusMessageWithContent() {
        #expect(PlayerLoadingPhase.failed("Custom error").statusMessage == "Custom error")
    }

    @Test("failed status message with empty string")
    func failedStatusMessageEmpty() {
        #expect(PlayerLoadingPhase.failed("").statusMessage == "Playback failed")
    }
}

@Suite("PlayerLoadingPhase Failover Explanation")
struct PlayerLoadingPhaseFailoverExplanationTests {

    @Test("switchingEngine provides explanation")
    func switchingEngineProvidesExplanation() {
        #expect(PlayerLoadingPhase.switchingEngine.failoverExplanation != nil)
    }

    @Test("other phases return nil explanation")
    func otherPhasesReturnNilExplanation() {
        #expect(PlayerLoadingPhase.connecting.failoverExplanation == nil)
        #expect(PlayerLoadingPhase.buffering.failoverExplanation == nil)
        #expect(PlayerLoadingPhase.preparingVideo.failoverExplanation == nil)
        #expect(PlayerLoadingPhase.retryingStream.failoverExplanation == nil)
        #expect(PlayerLoadingPhase.ready.failoverExplanation == nil)
        #expect(PlayerLoadingPhase.failed("test").failoverExplanation == nil)
    }
}

@Suite("PlayerLoadingPhase Phase Classification")
struct PlayerLoadingPhaseClassificationTests {

    @Test("isLoading for loading phases")
    func isLoadingForLoadingPhases() {
        #expect(PlayerLoadingPhase.connecting.isLoading == true)
        #expect(PlayerLoadingPhase.buffering.isLoading == true)
        #expect(PlayerLoadingPhase.preparingVideo.isLoading == true)
        #expect(PlayerLoadingPhase.switchingEngine.isLoading == true)
        #expect(PlayerLoadingPhase.retryingStream.isLoading == true)
    }

    @Test("isLoading for terminal phases")
    func isLoadingForTerminalPhases() {
        #expect(PlayerLoadingPhase.ready.isLoading == false)
        #expect(PlayerLoadingPhase.failed("test").isLoading == false)
    }

    @Test("isTerminal for terminal phases")
    func isTerminalForTerminalPhases() {
        #expect(PlayerLoadingPhase.ready.isTerminal == true)
        #expect(PlayerLoadingPhase.failed("test").isTerminal == true)
    }

    @Test("isTerminal for non-terminal phases")
    func isTerminalForNonTerminalPhases() {
        #expect(PlayerLoadingPhase.connecting.isTerminal == false)
        #expect(PlayerLoadingPhase.buffering.isTerminal == false)
        #expect(PlayerLoadingPhase.preparingVideo.isTerminal == false)
        #expect(PlayerLoadingPhase.switchingEngine.isTerminal == false)
        #expect(PlayerLoadingPhase.retryingStream.isTerminal == false)
    }
}
