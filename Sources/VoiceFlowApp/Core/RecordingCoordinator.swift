import Foundation
import Speech
import AVFoundation
@preconcurrency import ApplicationServices
import VoiceFlowProtocol

@MainActor
@Observable
final class RecordingCoordinator {
    let session: RecordingStateMachine
    private var sttClient: STTClientProtocol_App
    private var refinerClient: RefinerClientProtocol
    private var hud: HUDProtocol
    private let directInjector: TextInjecting
    private let clipboardInjector: TextInjecting
    private let prefs: PreferencesStore
    private let history: HistoryStore

    #if PROFEATURES
    enum InputMode { case normal, translate(String) }
    private var currentMode: InputMode = .normal
    #endif

    var onStateChanged: (() -> Void)?
    private var stopTask: Task<Void, Never>?
    private var cancelTask: Task<Void, Never>?
    private var errorResetTask: Task<Void, Never>?
    private var safetyTimerTask: Task<Void, Never>?
    private var fallbackTask: Task<Void, Never>?

    private(set) var isRecording: Bool = false
    private(set) var currentTranscript: String = ""
    private(set) var activeEngine: String = ""
    private var enhancedCrashed = false
    private var intentionalDisconnect = false
    private let skipPermissionCheck: Bool

    private func syncState() {
        isRecording = session.state.isActive
    }

    init(
        session: RecordingStateMachine = RecordingStateMachine(),
        sttClient: STTClientProtocol_App = STTXPCClient(),
        refinerClient: RefinerClientProtocol = RefinerXPCClient(),
        hud: HUDProtocol = FloatingHUD(),
        directInjector: TextInjecting? = nil,
        clipboardInjector: TextInjecting? = nil,
        prefs: PreferencesStore = .shared,
        history: HistoryStore = .shared,
        skipPermissionCheck: Bool = false
    ) {
        self.session = session
        self.sttClient = sttClient
        self.refinerClient = refinerClient
        self.hud = hud
        self.prefs = prefs
        self.history = history
        self.skipPermissionCheck = skipPermissionCheck
        self.clipboardInjector = clipboardInjector ?? ClipboardInjector()
        #if DIRECT
        self.directInjector = directInjector ?? AccessibilityInjector()
        #else
        self.directInjector = self.clipboardInjector
        #endif
    }

    func setup() {
        hud.onTap = { [weak self] in self?.toggle() }
        sttClient.onTranscript = { [weak self] text in
            guard let self, case .recording = self.session.state else { return }
            self.currentTranscript = text
            self.hud.updateTranscript(text)
        }
        sttClient.onAudioLevel = { [weak self] level in
            guard let self, case .recording = self.session.state else { return }
            self.hud.updateAudioLevel(level)
        }
        sttClient.onEngineChanged = { [weak self] engine in
            self?.activeEngine = engine
            self?.hud.updateEngine(engine)
        }
        sttClient.onError = { [weak self] message in
            self?.handleError(message)
        }
        sttClient.onConnectionInvalidated = { [weak self] in
            guard let self else { return }
            if self.intentionalDisconnect {
                self.intentionalDisconnect = false
                return
            }
            if self.activeEngine == "enhanced" && !self.enhancedCrashed {
                self.enhancedCrashed = true
                FileLogger.log("Enhanced engine crashed XPC, retrying with classic after delay")
                self.session.forceReset()
                self.syncState()
                self.onStateChanged?()
                self.fallbackTask = Task { [weak self] in
                    try? await Task.sleep(for: .seconds(1))
                    guard !Task.isCancelled, let self else { return }
                    self.startRecording(engineOverride: "classic")
                }
                return
            }
            guard self.session.state.isActive else { return }
            self.handleError(String(localized: "error.stt_connection_lost"))
        }
        refinerClient.onError = { [weak self] message in
            self?.handleError(message)
        }
    }

    func toggle() {
        #if PROFEATURES
        currentMode = .normal
        #endif
        handleToggle()
    }

    func cancel() {
        guard session.state.isActive else { return }
        cancelRecording()
    }

    #if PROFEATURES
    func toggleTranslation(_ targetLanguage: String) {
        currentMode = .translate(targetLanguage)
        handleToggle()
    }
    #endif

    private func handleToggle() {
        FileLogger.log("handleToggle state=\(String(describing: self.session.state)) stopTask=\(self.stopTask != nil) cancelTask=\(self.cancelTask != nil)")
        switch session.state {
        case .idle:
            startRecording()
        case .recording:
            stopRecording()
        case .starting, .processing:
            cancelRecording()
        default:
            FileLogger.log("handleToggle: default branch, no action")
            break
        }
    }

    func disconnect() {
        stopTask?.cancel()
        stopTask = nil
        cancelTask?.cancel()
        cancelTask = nil
        safetyTimerTask?.cancel()
        safetyTimerTask = nil
        errorResetTask?.cancel()
        errorResetTask = nil
        fallbackTask?.cancel()
        fallbackTask = nil
        session.forceReset()
        intentionalDisconnect = true
        sttClient.disconnect()
        refinerClient.disconnect()
    }

    func showPermissionError(_ message: String) {
        hud.showError(message)
    }

    // MARK: - Permissions

    private func ensurePermissions() -> Bool {
        if skipPermissionCheck { return true }
        let speechStatus = SFSpeechRecognizer.authorizationStatus()
        let micStatus = AVCaptureDevice.authorizationStatus(for: .audio)

        if speechStatus == .notDetermined || micStatus == .notDetermined {
            Task { await requestPermissions() }
            return false
        }
        if speechStatus != .authorized {
            showPermissionError(String(localized: "permission.speech"))
            return false
        }
        if micStatus != .authorized {
            showPermissionError(String(localized: "permission.microphone"))
            return false
        }
        return true
    }

    private nonisolated func requestPermissions() async {
        if SFSpeechRecognizer.authorizationStatus() == .notDetermined {
            _ = await withCheckedContinuation { cont in
                SFSpeechRecognizer.requestAuthorization { cont.resume(returning: $0) }
            }
        }
        if AVCaptureDevice.authorizationStatus(for: .audio) == .notDetermined {
            _ = await AVCaptureDevice.requestAccess(for: .audio)
        }
    }

    // MARK: - Private

    private func startRecording(engineOverride: String? = nil) {
        guard cancelTask == nil else { return }

        if !ensurePermissions() { return }

        if engineOverride == nil {
            enhancedCrashed = false
        }
        fallbackTask?.cancel()
        fallbackTask = nil
        errorResetTask?.cancel()
        errorResetTask = nil

        session.transition(.startRequested)
        currentTranscript = ""
        syncState()
        hud.showListening()
        onStateChanged?()

        let rawLocale = prefs.locale == "system" ? Locale.current.identifier : prefs.locale
        let localeID = Locale(identifier: rawLocale).identifier
        let engine = engineOverride ?? (enhancedCrashed ? "classic" : prefs.sttEngine.rawValue)
        FileLogger.log("startRecording engine=\(engine)")
        sttClient.startRecording(locale: localeID, engine: engine)
        session.transition(.micReady)
    }

    private func stopRecording() {
        FileLogger.log("stopRecording called, stopTask=\(self.stopTask != nil)")
        guard stopTask == nil else { FileLogger.log("stopRecording BLOCKED by existing stopTask"); return }
        session.transition(.stopRequested)
        syncState()
        onStateChanged?()

        stopTask = Task {
            defer { stopTask = nil }
            let rawTranscript = await sttClient.stopRecording() ?? ""

            guard !Task.isCancelled else { return }

            if rawTranscript.isEmpty {
                session.transition(.refinementDone)
                hud.hide()
                intentionalDisconnect = true
                sttClient.disconnect()
                syncState()
                onStateChanged?()
                return
            }

            let appContext = AppContext.current
            var refinerContext: [String: String] = [
                RefinerContextKey.category: appContext?.category.rawValue ?? "generic",
                RefinerContextKey.appName: appContext?.appName ?? "Unknown",
            ]
            if let bundleID = appContext?.bundleIdentifier {
                refinerContext[RefinerContextKey.bundleID] = bundleID
            }
            #if PROFEATURES
            if let appName = appContext?.appName,
               let customPrompt = prefs.appPrompts[appName], !customPrompt.isEmpty {
                refinerContext[RefinerContextKey.customPrompt] = customPrompt
            } else if !prefs.defaultPrompt.isEmpty {
                refinerContext[RefinerContextKey.customPrompt] = prefs.defaultPrompt
            }
            #else
            if !prefs.defaultPrompt.isEmpty {
                refinerContext[RefinerContextKey.customPrompt] = prefs.defaultPrompt
            }
            #endif

            let refined: String
            var timedOut = false

            #if PROFEATURES
            if case .translate(let targetLang) = currentMode, ProUpgradeManager.shared.isPro {
                hud.showProcessing(transcript: rawTranscript)
                let result = await refinerClient.translate(
                    text: rawTranscript, targetLanguage: targetLang
                )
                refined = result.0
                timedOut = result.1
            } else {
                (refined, timedOut) = await refineIfEnabled(rawTranscript, context: refinerContext)
            }
            currentMode = .normal
            #else
            (refined, timedOut) = await refineIfEnabled(rawTranscript, context: refinerContext)
            #endif

            guard !Task.isCancelled else { return }

            let canDirectPaste: Bool
            #if DIRECT
            canDirectPaste = prefs.useDirectPaste && AXIsProcessTrusted()
            #else
            canDirectPaste = false
            #endif

            let injector = canDirectPaste ? directInjector : clipboardInjector
            injector.inject(refined)
            session.transition(.refinementDone)

            history.add(
                rawTranscript: rawTranscript,
                refinedText: refined,
                appName: refinerContext[RefinerContextKey.appName] ?? "Unknown",
                category: refinerContext[RefinerContextKey.category] ?? "generic"
            )

            if timedOut {
                hud.showError(String(localized: "error.refinement_timeout"))
            } else if canDirectPaste {
                hud.showInserted(text: refined)
            } else {
                hud.showCopied(text: refined)
            }
            intentionalDisconnect = true
            sttClient.disconnect()
            syncState()
            onStateChanged?()
        }
    }

    private func cancelRecording() {
        FileLogger.log("cancelRecording called")
        session.transition(.cancel)
        let pendingStopTask = stopTask
        stopTask?.cancel()
        stopTask = nil
        cancelTask = Task {
            if let pendingStopTask {
                await pendingStopTask.value
            } else {
                let _ = await sttClient.stopRecording()
            }
            safetyTimerTask?.cancel()
            safetyTimerTask = nil
            cancelTask = nil
            session.transition(.reset)
            syncState()
            onStateChanged?()
        }
        // Safety: if cancelTask hangs, force-clear after 5 seconds
        safetyTimerTask?.cancel()
        safetyTimerTask = Task {
            try? await Task.sleep(for: .seconds(5))
            guard !Task.isCancelled else { return }
            cancelTask?.cancel()
            cancelTask = nil
            session.transition(.reset)
            syncState()
            onStateChanged?()
        }
        hud.hide()
        syncState()
        onStateChanged?()
    }

    private func handleError(_ message: String) {
        guard session.state.isActive else { return }
        stopTask?.cancel()
        stopTask = nil
        session.transition(.failed(message))
        hud.showError(message)
        syncState()
        onStateChanged?()

        errorResetTask?.cancel()
        errorResetTask = Task {
            try? await Task.sleep(for: .seconds(3))
            guard !Task.isCancelled, case .error = session.state else { return }
            session.transition(.reset)
            syncState()
            onStateChanged?()
        }
    }

    private func refineIfEnabled(_ text: String, context: [String: String]) async -> (String, Bool) {
        guard prefs.refinementMode == .refine else { return (text, false) }
        hud.showProcessing(transcript: text)
        return await refinerClient.refine(text: text, context: context)
    }
}
