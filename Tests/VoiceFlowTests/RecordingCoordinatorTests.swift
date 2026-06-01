import Testing
import Foundation
@testable import VoiceFlowApp

// MARK: - Mocks

@MainActor
final class MockSTTClient: STTClientProtocol_App {
    var onTranscript: ((String) -> Void)?
    var onAudioLevel: ((Float) -> Void)?
    var onError: ((String) -> Void)?
    var onConnectionInvalidated: (() -> Void)?

    var onEngineChanged: ((String) -> Void)?
    var startedWithLocale: String?
    var startedWithEngine: String?
    var startCallCount = 0
    var stopCallCount = 0
    var transcriptToReturn: String? = "Hello world"
    var stopDelay: Duration?
    var disconnected = false

    func startRecording(locale: String, engine: String = "enhanced") {
        startedWithLocale = locale
        startedWithEngine = engine
        startCallCount += 1
    }

    func stopRecording() async -> String? {
        stopCallCount += 1
        if let delay = stopDelay {
            try? await Task.sleep(for: delay)
        }
        return transcriptToReturn
    }

    func disconnect() {
        disconnected = true
    }
}

@MainActor
final class MockRefinerClient: RefinerClientProtocol {
    var onError: ((String) -> Void)?

    var lastText: String?
    var lastContext: [String: String]?
    var refinedToReturn: String = "Refined text"
    var shouldTimeout = false
    var disconnected = false

    func refine(text: String, context: [String: String]) async -> (String, Bool) {
        lastText = text
        lastContext = context
        return (shouldTimeout ? text : refinedToReturn, shouldTimeout)
    }

    #if PROFEATURES
    var lastTranslateTarget: String?
    var translatedToReturn: String = "Translated text"

    func translate(text: String, targetLanguage: String) async -> (String, Bool) {
        lastText = text
        lastTranslateTarget = targetLanguage
        return (shouldTimeout ? text : translatedToReturn, shouldTimeout)
    }
    #endif

    func disconnect() {
        disconnected = true
    }
}

@MainActor
final class MockHUD: HUDProtocol {
    var onTap: (() -> Void)?
    var states: [String] = []

    func showListening() { states.append("listening") }
    func showProcessing(transcript: String) { states.append("processing:\(transcript)") }
    func showCopied(text: String) { states.append("copied:\(text)") }
    func showInserted(text: String) { states.append("inserted:\(text)") }
    func showError(_ message: String) { states.append("error:\(message)") }
    func updateTranscript(_ text: String) { states.append("transcript:\(text)") }
    func updateAudioLevel(_ level: Float) { states.append("level") }
    func updateEngine(_ engine: String) { states.append("engine:\(engine)") }
    func hide() { states.append("hide") }
}

@MainActor
final class MockInjector: @preconcurrency TextInjecting {
    var injectedText: String?

    nonisolated func inject(_ text: String) {
        MainActor.assumeIsolated {
            injectedText = text
        }
    }
}

// MARK: - Tests

@MainActor
@Suite("RecordingCoordinator")
struct RecordingCoordinatorTests {

    private func makeCoordinator(
        directInjector: MockInjector? = nil,
        clipboardInjector: MockInjector? = nil
    ) -> (RecordingCoordinator, MockSTTClient, MockRefinerClient, MockHUD, MockInjector, MockInjector) {
        let stt = MockSTTClient()
        let refiner = MockRefinerClient()
        let hud = MockHUD()
        let shared = MockInjector()
        let direct = directInjector ?? shared
        let clipboard = clipboardInjector ?? shared
        let coordinator = RecordingCoordinator(
            sttClient: stt,
            refinerClient: refiner,
            hud: hud,
            directInjector: direct,
            clipboardInjector: clipboard,
            skipPermissionCheck: true
        )
        coordinator.setup()
        return (coordinator, stt, refiner, hud, direct, clipboard)
    }

    // MARK: - Start/Stop flow

    @Test func startRecordingShowsHUD() async {
        let (coordinator, stt, _, hud, _, _) = makeCoordinator()

        coordinator.toggle()

        #expect(stt.startedWithLocale != nil)
        #expect(hud.states.contains("listening"))
        #expect(coordinator.isRecording)
    }

    @Test func fullRecordingFlowInjectsRefinedText() async {
        let (coordinator, stt, refiner, hud, injector, _) = makeCoordinator()
        stt.transcriptToReturn = "Hello world"
        refiner.refinedToReturn = "Hello, world."

        coordinator.toggle() // start
        #expect(coordinator.isRecording)

        coordinator.toggle() // stop
        // Wait for the async stopTask to complete
        try? await Task.sleep(for: .milliseconds(50))

        #expect(stt.stopCallCount == 1)
        #expect(refiner.lastText == "Hello world")
        #expect(injector.injectedText == "Hello, world.")
        #expect(hud.states.contains("listening"))
        #expect(hud.states.contains { $0.starts(with: "processing:") })
        #expect(!coordinator.isRecording)
    }

    @Test func emptyTranscriptSkipsRefinerAndHides() async {
        let (coordinator, stt, refiner, hud, injector, _) = makeCoordinator()
        stt.transcriptToReturn = nil

        coordinator.toggle() // start
        coordinator.toggle() // stop
        try? await Task.sleep(for: .milliseconds(50))

        #expect(refiner.lastText == nil)
        #expect(injector.injectedText == nil)
        #expect(hud.states.contains("hide"))
    }

    // MARK: - Refiner timeout

    @Test func refinerTimeoutShowsError() async {
        let (coordinator, stt, refiner, hud, injector, _) = makeCoordinator()
        stt.transcriptToReturn = "Test input"
        refiner.shouldTimeout = true

        coordinator.toggle() // start
        coordinator.toggle() // stop
        try? await Task.sleep(for: .milliseconds(50))

        #expect(injector.injectedText == "Test input")
        #expect(hud.states.contains { $0.hasPrefix("error:") && $0.contains("timeout") })
    }

    // MARK: - Cancel

    @Test func cancelDuringProcessingResetsToIdle() async {
        let (coordinator, stt, _, hud, injector, _) = makeCoordinator()
        stt.transcriptToReturn = "Hello"
        stt.stopDelay = .milliseconds(500)

        coordinator.toggle() // start → recording
        #expect(coordinator.isRecording)

        coordinator.toggle() // stop → processing (stopTask starts, awaiting slow XPC)
        #expect(coordinator.session.state == .processing(coordinator.session.state.sessionID!))

        coordinator.toggle() // cancel during processing
        try? await Task.sleep(for: .milliseconds(100))

        #expect(hud.states.contains("hide"))
        #expect(injector.injectedText == nil)

        // Wait for cancelTask to complete
        try? await Task.sleep(for: .milliseconds(600))

        #expect(coordinator.session.state == .idle)
    }

    @Test func cancelResetsToIdleAndAllowsNewSession() async {
        let (coordinator, stt, refiner, _, injector, _) = makeCoordinator()
        stt.transcriptToReturn = "First"
        stt.stopDelay = .milliseconds(300)

        // Session 1: start → stop → cancel during processing
        coordinator.toggle()
        coordinator.toggle()
        coordinator.toggle() // cancel
        try? await Task.sleep(for: .milliseconds(500))

        #expect(coordinator.session.state == .idle)
        #expect(injector.injectedText == nil)

        // Session 2: should work normally
        stt.stopDelay = nil
        stt.transcriptToReturn = "Second"
        refiner.refinedToReturn = "Second refined"

        coordinator.toggle()
        #expect(coordinator.isRecording)
        coordinator.toggle()
        try? await Task.sleep(for: .milliseconds(50))

        #expect(injector.injectedText == "Second refined")
        #expect(coordinator.session.state == .idle)
    }

    @Test func safetyTimerForcesResetWhenCancelHangs() async {
        let (coordinator, stt, _, hud, _, _) = makeCoordinator()
        stt.transcriptToReturn = "Hello"
        stt.stopDelay = .seconds(10) // Simulate hung XPC

        coordinator.toggle() // start
        coordinator.toggle() // stop → processing
        coordinator.toggle() // cancel during processing

        #expect(hud.states.contains("hide"))

        // Safety timer fires after 5 seconds
        try? await Task.sleep(for: .seconds(6))

        #expect(coordinator.session.state == .idle)
    }

    @Test func disconnectDuringCancelCleansUp() async {
        let (coordinator, stt, _, _, _, _) = makeCoordinator()
        stt.transcriptToReturn = "Hello"
        stt.stopDelay = .milliseconds(500)

        coordinator.toggle() // start
        coordinator.toggle() // stop → processing
        coordinator.toggle() // cancel

        coordinator.disconnect()

        #expect(coordinator.session.state == .idle)
    }

    // MARK: - Disconnect

    @Test func disconnectInvalidatesBothClients() {
        let (coordinator, stt, refiner, _, _, _) = makeCoordinator()

        coordinator.disconnect()

        #expect(stt.disconnected)
        #expect(refiner.disconnected)
        #expect(coordinator.session.state == .idle)
    }

    @Test func disconnectDuringRecordingResetsState() async {
        let (coordinator, stt, refiner, _, _, _) = makeCoordinator()

        coordinator.toggle() // start → recording
        #expect(coordinator.isRecording)

        coordinator.disconnect()

        #expect(coordinator.session.state == .idle)
        #expect(stt.disconnected)
        #expect(refiner.disconnected)
    }

    // MARK: - Error handling

    @Test func sttErrorDuringRecordingShowsError() async {
        let (coordinator, stt, _, hud, _, _) = makeCoordinator()

        coordinator.toggle() // start → recording
        #expect(coordinator.isRecording)

        stt.onError?("Mic disconnected")
        try? await Task.sleep(for: .milliseconds(50))

        #expect(hud.states.contains("error:Mic disconnected"))
        #expect(!coordinator.isRecording)
    }

    @Test func errorWhileIdleIsIgnored() async {
        let (coordinator, stt, _, hud, _, _) = makeCoordinator()

        #expect(!coordinator.isRecording)
        stt.onError?("Stale error")

        #expect(!hud.states.contains("error:Stale error"))
    }

    // MARK: - State change callback

    @Test func onStateChangedFiresDuringToggle() {
        let (coordinator, _, _, _, _, _) = makeCoordinator()
        var callCount = 0
        coordinator.onStateChanged = { callCount += 1 }

        coordinator.toggle() // start
        #expect(callCount >= 1)
    }

    // MARK: - Engine change

    @Test func engineChangedUpdatesActiveEngine() {
        let (coordinator, stt, _, hud, _, _) = makeCoordinator()
        coordinator.toggle()
        stt.onEngineChanged?("enhanced")
        #expect(coordinator.activeEngine == "enhanced")
        #expect(hud.states.contains("engine:enhanced"))
    }

    @Test func engineChangedWhileIdleStillUpdates() {
        let (coordinator, stt, _, hud, _, _) = makeCoordinator()
        stt.onEngineChanged?("classic")
        #expect(coordinator.activeEngine == "classic")
        #expect(hud.states.contains("engine:classic"))
    }

    // MARK: - Permission error

    @Test func showPermissionErrorDelegatesToHUD() {
        let (coordinator, _, _, hud, _, _) = makeCoordinator()

        coordinator.showPermissionError("Mic permission denied")

        #expect(hud.states.contains("error:Mic permission denied"))
    }

    // MARK: - Empty string transcript

    @Test func emptyStringTranscriptSkipsRefiner() async {
        let (coordinator, stt, refiner, hud, injector, _) = makeCoordinator()
        stt.transcriptToReturn = ""

        coordinator.toggle()
        coordinator.toggle()
        try? await Task.sleep(for: .milliseconds(50))

        #expect(refiner.lastText == nil)
        #expect(injector.injectedText == nil)
        #expect(hud.states.contains("hide"))
    }

    // MARK: - Connection invalidated

    @Test func connectionInvalidatedDuringRecording() async {
        let (coordinator, stt, _, hud, _, _) = makeCoordinator()

        coordinator.toggle()
        #expect(coordinator.isRecording)

        stt.onConnectionInvalidated?()
        try? await Task.sleep(for: .milliseconds(50))

        #expect(hud.states.contains { $0.starts(with: "error:") })
        #expect(!coordinator.isRecording)
    }

    @Test func enhancedCrashFallsBackToClassic() async {
        let (coordinator, stt, _, hud, _, _) = makeCoordinator()

        coordinator.toggle()
        #expect(stt.startCallCount == 1)

        stt.onEngineChanged?("enhanced")
        stt.onConnectionInvalidated?()
        try? await Task.sleep(for: .milliseconds(1200))

        #expect(coordinator.isRecording)
        #expect(stt.startCallCount == 2)
        #expect(stt.startedWithEngine == "classic")
        #expect(!hud.states.contains { $0.starts(with: "error:") })
    }

    @Test func classicCrashShowsError() async {
        let (coordinator, stt, _, hud, _, _) = makeCoordinator()

        coordinator.toggle()
        stt.onEngineChanged?("classic")
        stt.onConnectionInvalidated?()
        try? await Task.sleep(for: .milliseconds(50))

        #expect(hud.states.contains { $0.starts(with: "error:") })
        #expect(!coordinator.isRecording)
    }

    @Test func enhancedCrashRetryOnlyOnce() async {
        let (coordinator, stt, _, hud, _, _) = makeCoordinator()

        coordinator.toggle()
        stt.onEngineChanged?("enhanced")
        stt.onConnectionInvalidated?()
        try? await Task.sleep(for: .milliseconds(1200))

        #expect(stt.startCallCount == 2)

        stt.onEngineChanged?("classic")
        stt.onConnectionInvalidated?()
        try? await Task.sleep(for: .milliseconds(50))

        #expect(hud.states.contains { $0.starts(with: "error:") })
    }

    // MARK: - Consecutive sessions

    @Test func secondSessionWorksAfterFirst() async {
        let (coordinator, stt, refiner, _, injector, _) = makeCoordinator()
        stt.transcriptToReturn = "First"
        refiner.refinedToReturn = "First refined"

        coordinator.toggle()
        coordinator.toggle()
        try? await Task.sleep(for: .milliseconds(50))

        #expect(injector.injectedText == "First refined")
        #expect(!coordinator.isRecording)

        stt.transcriptToReturn = "Second"
        refiner.refinedToReturn = "Second refined"
        injector.injectedText = nil

        coordinator.toggle()
        #expect(coordinator.isRecording)
        coordinator.toggle()
        try? await Task.sleep(for: .milliseconds(50))

        #expect(injector.injectedText == "Second refined")
        #expect(stt.stopCallCount == 2)
        #expect(!coordinator.isRecording)
    }

    @Test func secondSessionWorksWithSlowStop() async {
        let (coordinator, stt, refiner, _, injector, _) = makeCoordinator()
        stt.transcriptToReturn = "First"
        stt.stopDelay = .milliseconds(200)
        refiner.refinedToReturn = "First refined"

        coordinator.toggle()
        coordinator.toggle()
        try? await Task.sleep(for: .milliseconds(300))

        #expect(injector.injectedText == "First refined")
        #expect(!coordinator.isRecording)

        stt.transcriptToReturn = "Second"
        refiner.refinedToReturn = "Second refined"
        injector.injectedText = nil

        coordinator.toggle()
        #expect(coordinator.isRecording)
        coordinator.toggle()
        try? await Task.sleep(for: .milliseconds(300))

        #expect(injector.injectedText == "Second refined")
        #expect(stt.stopCallCount == 2)
    }

    @Test func threeConsecutiveSessionsAllWork() async {
        let (coordinator, stt, refiner, _, injector, _) = makeCoordinator()
        stt.stopDelay = .milliseconds(100)

        for i in 1...3 {
            stt.transcriptToReturn = "Session \(i)"
            refiner.refinedToReturn = "Refined \(i)"

            coordinator.toggle()
            #expect(coordinator.isRecording)
            coordinator.toggle()
            try? await Task.sleep(for: .milliseconds(200))

            #expect(injector.injectedText == "Refined \(i)")
            #expect(!coordinator.isRecording)
        }
        #expect(stt.stopCallCount == 3)
    }

    @Test func connectionInvalidatedWhileIdleIgnored() {
        let (coordinator, stt, _, hud, _, _) = makeCoordinator()

        stt.onConnectionInvalidated?()

        #expect(!hud.states.contains { $0.starts(with: "error:") })
    }

    // MARK: - State change on stop

    @Test func onStateChangedFiresDuringStop() async {
        let (coordinator, _, _, _, _, _) = makeCoordinator()
        var callCount = 0
        coordinator.onStateChanged = { callCount += 1 }

        coordinator.toggle() // start
        let beforeStop = callCount
        coordinator.toggle() // stop
        try? await Task.sleep(for: .milliseconds(50))

        #expect(callCount > beforeStop)
    }

    @Test func onStateChangedFiresOnError() async {
        let (coordinator, stt, _, _, _, _) = makeCoordinator()
        var callCount = 0
        coordinator.onStateChanged = { callCount += 1 }

        coordinator.toggle()
        let beforeError = callCount
        stt.onError?("test error")
        try? await Task.sleep(for: .milliseconds(50))

        #expect(callCount > beforeError)
    }

    // MARK: - Output method switching

    @Test func clipboardModeUsesClipboardInjector() async {
        let direct = MockInjector()
        let clipboard = MockInjector()
        let (coordinator, stt, refiner, _, _, _) = makeCoordinator(
            directInjector: direct, clipboardInjector: clipboard
        )
        PreferencesStore.shared.useDirectPaste = false
        defer { PreferencesStore.shared.useDirectPaste = true }

        stt.transcriptToReturn = "Test"
        refiner.refinedToReturn = "Refined"

        coordinator.toggle()
        coordinator.toggle()
        try? await Task.sleep(for: .milliseconds(50))

        #expect(clipboard.injectedText == "Refined")
        #expect(direct.injectedText == nil)
    }

    @Test func directModeUsesDirectInjector() async {
        let direct = MockInjector()
        let clipboard = MockInjector()
        let (coordinator, stt, refiner, _, _, _) = makeCoordinator(
            directInjector: direct, clipboardInjector: clipboard
        )
        PreferencesStore.shared.useDirectPaste = true

        stt.transcriptToReturn = "Test"
        refiner.refinedToReturn = "Refined"

        coordinator.toggle()
        coordinator.toggle()
        try? await Task.sleep(for: .milliseconds(50))

        #if DIRECT
        #expect(direct.injectedText == "Refined")
        #expect(clipboard.injectedText == nil)
        #else
        // Non-DIRECT builds: directInjector falls back to clipboardInjector in init
        #expect(clipboard.injectedText == "Refined")
        #endif
    }
}
