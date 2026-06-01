import Foundation

@MainActor
final class RecordingCoordinator {
    let session: RecordingStateMachine
    private var sttClient: STTClientProtocol_App
    private var refinerClient: RefinerClientProtocol
    private var hud: HUDProtocol
    private let injector: TextInjecting
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

    var isRecording: Bool { session.state.isActive }

    init(
        session: RecordingStateMachine = RecordingStateMachine(),
        sttClient: STTClientProtocol_App = STTXPCClient(),
        refinerClient: RefinerClientProtocol = RefinerXPCClient(),
        hud: HUDProtocol = FloatingHUD(),
        injector: TextInjecting? = nil,
        prefs: PreferencesStore = .shared,
        history: HistoryStore = .shared
    ) {
        self.session = session
        self.sttClient = sttClient
        self.refinerClient = refinerClient
        self.hud = hud
        self.prefs = prefs
        self.history = history
        #if DIRECT
        self.injector = injector ?? AccessibilityInjector()
        #else
        self.injector = injector ?? ClipboardInjector()
        #endif
    }

    func setup() {
        hud.onTap = { [weak self] in self?.toggle() }
        sttClient.onTranscript = { [weak self] text in
            guard let self, case .recording = self.session.state else { return }
            self.hud.updateTranscript(text)
        }
        sttClient.onAudioLevel = { [weak self] level in
            guard let self, case .recording = self.session.state else { return }
            self.hud.updateAudioLevel(level)
        }
        sttClient.onError = { [weak self] message in
            self?.handleError(message)
        }
        sttClient.onConnectionInvalidated = { [weak self] in
            guard let self, self.session.state.isActive else { return }
            self.handleError("Speech service connection lost.")
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

    #if PROFEATURES
    func toggleTranslation(_ targetLanguage: String) {
        currentMode = .translate(targetLanguage)
        handleToggle()
    }
    #endif

    private func handleToggle() {
        switch session.state {
        case .idle:
            startRecording()
        case .recording:
            stopRecording()
        case .starting, .processing:
            cancelRecording()
        default:
            break
        }
    }

    func disconnect() {
        sttClient.disconnect()
        refinerClient.disconnect()
    }

    func showPermissionError(_ message: String) {
        hud.showError(message)
    }

    // MARK: - Private

    private func startRecording() {
        guard cancelTask == nil else { return }

        errorResetTask?.cancel()
        errorResetTask = nil

        session.transition(.startRequested)
        hud.showListening()
        onStateChanged?()

        let rawLocale = prefs.locale == "system" ? Locale.current.identifier : prefs.locale
        let localeID = Locale(identifier: rawLocale).identifier
        sttClient.startRecording(locale: localeID)
        session.transition(.micReady)
    }

    private func stopRecording() {
        session.transition(.stopRequested)
        onStateChanged?()

        stopTask = Task {
            let rawTranscript = await sttClient.stopRecording() ?? ""

            guard !Task.isCancelled else { return }

            if rawTranscript.isEmpty {
                session.transition(.refinementDone)
                hud.hide()
                onStateChanged?()
                return
            }

            let context = AppContext.current
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
                (refined, timedOut) = await refineIfEnabled(rawTranscript, context: context)
            }
            currentMode = .normal
            #else
            (refined, timedOut) = await refineIfEnabled(rawTranscript, context: context)
            #endif

            guard !Task.isCancelled else { return }

            injector.inject(refined)
            session.transition(.refinementDone)

            history.add(
                rawTranscript: rawTranscript,
                refinedText: refined,
                appName: context?.appName ?? "Unknown",
                category: context?.category.rawValue ?? "generic"
            )

            if timedOut {
                hud.showError("Refinement skipped (timeout)")
            } else {
                #if DIRECT
                hud.showInserted(text: refined)
                #else
                hud.showCopied(text: refined)
                #endif
            }
            onStateChanged?()
        }
    }

    private func cancelRecording() {
        session.transition(.cancel)
        stopTask?.cancel()
        stopTask = nil
        cancelTask = Task {
            let _ = await sttClient.stopRecording()
            cancelTask = nil
        }
        // Safety: if cancelTask hangs, force-clear after 5 seconds
        Task {
            try? await Task.sleep(for: .seconds(5))
            if cancelTask != nil {
                cancelTask?.cancel()
                cancelTask = nil
            }
        }
        hud.hide()
        onStateChanged?()
    }

    private func handleError(_ message: String) {
        guard session.state.isActive else { return }
        stopTask?.cancel()
        stopTask = nil
        session.transition(.failed(message))
        hud.showError(message)
        onStateChanged?()

        errorResetTask?.cancel()
        errorResetTask = Task {
            try? await Task.sleep(for: .seconds(3))
            guard !Task.isCancelled, case .error = session.state else { return }
            session.transition(.reset)
            onStateChanged?()
        }
    }

    private func refineIfEnabled(_ text: String, context: AppContext?) async -> (String, Bool) {
        guard prefs.refinementMode == .refine else { return (text, false) }
        #if PROFEATURES
        guard ProUpgradeManager.shared.isPro else { return (text, false) }
        #endif
        hud.showProcessing(transcript: text)
        return await refinerClient.refine(
            text: text,
            category: context?.category.rawValue ?? "generic"
        )
    }
}
