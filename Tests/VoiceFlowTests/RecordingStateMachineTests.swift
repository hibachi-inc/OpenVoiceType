import Testing
@testable import VoiceFlowApp

@MainActor
@Suite("RecordingStateMachine")
struct RecordingStateMachineTests {

    // MARK: - Happy path

    @Test func normalRecordingFlow() {
        let sm = RecordingStateMachine()
        #expect(sm.state == .idle)

        let starting = sm.transition(.startRequested)
        #expect(starting.isActive)
        #expect(starting.sessionID != nil)

        let recording = sm.transition(.micReady)
        guard case .recording(let id) = recording else {
            Issue.record("Expected .recording, got \(recording)")
            return
        }

        let processing = sm.transition(.stopRequested)
        guard case .processing(let pid) = processing else {
            Issue.record("Expected .processing, got \(processing)")
            return
        }
        #expect(pid == id)

        let idle = sm.transition(.refinementDone)
        #expect(idle == .idle)
    }

    // MARK: - Cancel paths

    @Test func cancelDuringStarting() {
        let sm = RecordingStateMachine()
        sm.transition(.startRequested)

        let cancelled = sm.transition(.cancel)
        guard case .cancelled = cancelled else {
            Issue.record("Expected .cancelled, got \(cancelled)")
            return
        }
        #expect(!cancelled.isActive)

        let idle = sm.transition(.reset)
        #expect(idle == .idle)
    }

    @Test func cancelDuringRecording() {
        let sm = RecordingStateMachine()
        sm.transition(.startRequested)
        sm.transition(.micReady)

        let cancelled = sm.transition(.cancel)
        guard case .cancelled = cancelled else {
            Issue.record("Expected .cancelled, got \(cancelled)")
            return
        }
    }

    @Test func cancelDuringProcessing() {
        let sm = RecordingStateMachine()
        sm.transition(.startRequested)
        sm.transition(.micReady)
        sm.transition(.stopRequested)

        let cancelled = sm.transition(.cancel)
        guard case .cancelled = cancelled else {
            Issue.record("Expected .cancelled, got \(cancelled)")
            return
        }
    }

    @Test func stopRequestedDuringStartingCancels() {
        let sm = RecordingStateMachine()
        sm.transition(.startRequested)

        let result = sm.transition(.stopRequested)
        guard case .cancelled = result else {
            Issue.record("Expected .cancelled for stopRequested during .starting, got \(result)")
            return
        }
    }

    // MARK: - Error paths

    @Test func errorDuringStarting() {
        let sm = RecordingStateMachine()
        sm.transition(.startRequested)

        let error = sm.transition(.failed("mic unavailable"))
        guard case .error(_, let msg) = error else {
            Issue.record("Expected .error, got \(error)")
            return
        }
        #expect(msg == "mic unavailable")
        #expect(!error.isActive)
    }

    @Test func errorDuringRecording() {
        let sm = RecordingStateMachine()
        sm.transition(.startRequested)
        sm.transition(.micReady)

        let error = sm.transition(.failed("connection lost"))
        guard case .error = error else {
            Issue.record("Expected .error, got \(error)")
            return
        }

        let idle = sm.transition(.reset)
        #expect(idle == .idle)
    }

    @Test func errorDuringProcessing() {
        let sm = RecordingStateMachine()
        sm.transition(.startRequested)
        sm.transition(.micReady)
        sm.transition(.stopRequested)

        let error = sm.transition(.failed("refiner crash"))
        guard case .error = error else {
            Issue.record("Expected .error, got \(error)")
            return
        }
    }

    // MARK: - Invalid transitions (should be no-ops)

    @Test func invalidTransitionsAreNoOps() {
        let sm = RecordingStateMachine()

        let still = sm.transition(.micReady)
        #expect(still == .idle)

        let still2 = sm.transition(.stopRequested)
        #expect(still2 == .idle)

        let still3 = sm.transition(.refinementDone)
        #expect(still3 == .idle)
    }

    // MARK: - Session ID consistency

    @Test func sessionIDPreservedAcrossTransitions() {
        let sm = RecordingStateMachine()
        let starting = sm.transition(.startRequested)
        let startID = starting.sessionID!

        let recording = sm.transition(.micReady)
        #expect(recording.sessionID == startID)

        let processing = sm.transition(.stopRequested)
        #expect(processing.sessionID == startID)
    }

    @Test func newSessionGetsNewID() {
        let sm = RecordingStateMachine()

        sm.transition(.startRequested)
        let id1 = sm.state.sessionID!
        sm.transition(.micReady)
        sm.transition(.stopRequested)
        sm.transition(.refinementDone)

        sm.transition(.startRequested)
        let id2 = sm.state.sessionID!
        #expect(id1 != id2)
    }

    // MARK: - Cancelled → refinementDone (late arrival)

    @Test func refinementDoneAfterCancelResetsToIdle() {
        let sm = RecordingStateMachine()
        sm.transition(.startRequested)
        sm.transition(.micReady)
        sm.transition(.stopRequested)
        sm.transition(.cancel)

        let idle = sm.transition(.refinementDone)
        #expect(idle == .idle)
    }

    // MARK: - No-op on invalid events in terminal states

    @Test func errorStateIgnoresStartRequested() {
        let sm = RecordingStateMachine()
        sm.transition(.startRequested)
        sm.transition(.micReady)
        sm.transition(.failed("test"))

        let still = sm.transition(.startRequested)
        guard case .error = still else {
            Issue.record("Expected .error, got \(still)")
            return
        }
    }

    @Test func cancelledStateIgnoresStartRequested() {
        let sm = RecordingStateMachine()
        sm.transition(.startRequested)
        sm.transition(.cancel)

        let still = sm.transition(.startRequested)
        guard case .cancelled = still else {
            Issue.record("Expected .cancelled, got \(still)")
            return
        }
    }

    @Test func recordingIgnoresDuplicateMicReady() {
        let sm = RecordingStateMachine()
        sm.transition(.startRequested)
        let recording = sm.transition(.micReady)
        let id = recording.sessionID

        let still = sm.transition(.micReady)
        #expect(still == recording)
        #expect(still.sessionID == id)
    }

    @Test func processingIgnoresDuplicateStopRequested() {
        let sm = RecordingStateMachine()
        sm.transition(.startRequested)
        sm.transition(.micReady)
        let processing = sm.transition(.stopRequested)

        let still = sm.transition(.stopRequested)
        #expect(still == processing)
    }

    @Test func cancelledPreservesSessionID() {
        let sm = RecordingStateMachine()
        sm.transition(.startRequested)
        let recording = sm.transition(.micReady)
        let id = recording.sessionID

        let cancelled = sm.transition(.cancel)
        #expect(cancelled.sessionID == id)
    }

    @Test func errorPreservesSessionID() {
        let sm = RecordingStateMachine()
        sm.transition(.startRequested)
        let recording = sm.transition(.micReady)
        let id = recording.sessionID

        let error = sm.transition(.failed("test"))
        #expect(error.sessionID == id)
    }
}
