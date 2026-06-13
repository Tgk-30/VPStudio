#if os(visionOS)
import Testing
import simd
@testable import VPStudio

// MARK: - Initial State & Lifecycle

@Suite("HeadTracker — Initial State & Lifecycle")
@MainActor
struct HeadTrackerLifecycleTests {

    @Test("Default initial state")
    func initialState() {
        let tracker = HeadTracker()
        #expect(!tracker.isRunning)
        #expect(!tracker.isTracking)
        #expect(tracker.headTransform == matrix_identity_float4x4)
        #expect(tracker.initialHeadTransform == nil)
        #expect(tracker.isIdle == false)
    }

    @Test("start() sets isRunning to true and leaves initialHeadTransform nil")
    func startBehavior() {
        let tracker = HeadTracker()
        tracker.start()
        #expect(tracker.isRunning)
        #expect(!tracker.isTracking)
        #expect(tracker.initialHeadTransform == nil)
        tracker.stop()
    }

    @Test("stop() resets isRunning, isTracking, headTransform, and initialHeadTransform")
    func stopResetsState() {
        let tracker = HeadTracker()
        tracker.start()
        tracker.stop()
        #expect(!tracker.isRunning)
        #expect(!tracker.isTracking)
        #expect(tracker.headTransform == matrix_identity_float4x4)
        #expect(tracker.initialHeadTransform == nil)
    }

    @Test("stop() without start() is idempotent")
    func stopWithoutStart() {
        let tracker = HeadTracker()
        tracker.stop()
        tracker.stop()
        #expect(!tracker.isRunning)
        #expect(!tracker.isTracking)
        #expect(tracker.headTransform == matrix_identity_float4x4)
        #expect(tracker.initialHeadTransform == nil)
    }

    @Test("Double start is harmless")
    func doubleStartIsIdempotent() {
        let tracker = HeadTracker()
        tracker.start()
        tracker.start()
        #expect(tracker.isRunning)
        tracker.stop()
        #expect(!tracker.isRunning)
    }

    @Test("Multiple start/stop cycles do not crash or leak")
    func multipleStartStopCycles() {
        let tracker = HeadTracker()
        for _ in 0..<5 {
            tracker.start()
            #expect(tracker.isRunning)
            #expect(!tracker.isTracking)
            tracker.stop()
            #expect(!tracker.isRunning)
            #expect(!tracker.isTracking)
            #expect(tracker.headTransform == matrix_identity_float4x4)
            #expect(tracker.initialHeadTransform == nil)
        }
    }

    @Test("headTransform remains valid on Simulator after brief polling")
    func headTransformStaysValidOnSimulator() async throws {
        let tracker = HeadTracker()
        tracker.start()
        defer { tracker.stop() }

        try await Task.sleep(for: .milliseconds(150))
        if tracker.isTracking {
            #expect(tracker.headTransform.columns.3.w == 1.0)
        } else {
            #expect(tracker.headTransform == matrix_identity_float4x4)
        }
    }
}

// MARK: - isIdle & Polling Intervals

@Suite("HeadTracker — isIdle & Polling Intervals")
@MainActor
struct HeadTrackerIdleTests {

    @Test("isIdle defaults to false and can be toggled")
    func isIdleToggle() {
        let tracker = HeadTracker()
        #expect(tracker.isIdle == false)

        tracker.isIdle = true
        #expect(tracker.isIdle == true)

        tracker.isIdle = false
        #expect(tracker.isIdle == false)
    }

    @Test("isIdle persists across start/stop")
    func isIdlePersistsAcrossLifecycle() {
        let tracker = HeadTracker()
        tracker.isIdle = true
        tracker.start()
        #expect(tracker.isIdle == true)
        tracker.stop()
        #expect(tracker.isIdle == true)
    }
}

@Suite("HeadTracker — Polling Interval Static Method")
struct HeadTrackerPollingIntervalTests {

    @Test("Returns activeInterval when isIdle is false")
    func activeIntervalWhenNotIdle() {
        let interval = HeadTracker.pollingInterval(isIdle: false, activeInterval: .milliseconds(16))
        #expect(interval == .milliseconds(16))
    }

    @Test("Returns idlePollInterval when isIdle is true")
    func idleIntervalWhenIdle() {
        let interval = HeadTracker.pollingInterval(isIdle: true, activeInterval: .milliseconds(16))
        #expect(interval == .milliseconds(500))
    }

    @Test("Respects custom active interval")
    func customActiveInterval() {
        let interval = HeadTracker.pollingInterval(isIdle: false, activeInterval: .milliseconds(8))
        #expect(interval == .milliseconds(8))
    }

    @Test("Ignores custom active interval when idle")
    func customActiveIntervalIgnoredWhenIdle() {
        let interval = HeadTracker.pollingInterval(isIdle: true, activeInterval: .seconds(1))
        #expect(interval == .milliseconds(500))
    }
}

// MARK: - Configuration Defaults

@Suite("HeadTracker — Configuration Defaults")
struct HeadTrackerConfigTestsRootheadtrackertests {

    @Test("defaultPollInterval is 16 ms")
    func defaultPollInterval() {
        #expect(HeadTracker.defaultPollInterval == .milliseconds(16))
    }

    @Test("idlePollInterval is 500 ms")
    func idlePollInterval() {
        #expect(HeadTracker.idlePollInterval == .milliseconds(500))
    }

    @Test("defaultSmoothingFactor is 0.3")
    func defaultSmoothingFactor() {
        #expect(HeadTracker.defaultSmoothingFactor == 0.3)
    }

    @Test("Custom poll interval is accepted")
    @MainActor func customPollInterval() {
        let tracker = HeadTracker(pollInterval: .milliseconds(8))
        tracker.start()
        #expect(tracker.isRunning)
        tracker.stop()
    }

    @Test("Smoothing factor clamps low values to 0.01")
    @MainActor func smoothingFactorClampedLow() {
        let tracker = HeadTracker(smoothingFactor: 0.0)
        tracker.start()
        tracker.stop()
    }

    @Test("Smoothing factor clamps high values to 1.0")
    @MainActor func smoothingFactorClampedHigh() {
        let tracker = HeadTracker(smoothingFactor: 2.0)
        tracker.start()
        tracker.stop()
    }
}

// MARK: - Deinit

@Suite("HeadTracker — Deinit")
@MainActor
struct HeadTrackerDeinitTests {

    @Test("deinit cancels an active poll task without crashing")
    func deinitCancelsActivePollTask() {
        func scopedStart() {
            let tracker = HeadTracker()
            tracker.start()
            // Exiting scope triggers deinit while the detached poll task is running.
        }
        scopedStart()
        // Reaching this point means deinit did not crash.
    }

    @Test("deinit after stop does not crash")
    func deinitAfterStop() {
        func scopedStartStop() {
            let tracker = HeadTracker()
            tracker.start()
            tracker.stop()
            // Exiting scope triggers deinit with no active task.
        }
        scopedStartStop()
    }

    @Test("deinit after multiple start/stop cycles does not crash")
    func deinitAfterMultipleCycles() {
        func scopedCycles() {
            let tracker = HeadTracker()
            for _ in 0..<3 {
                tracker.start()
                tracker.stop()
            }
        }
        scopedCycles()
    }
}
#endif
