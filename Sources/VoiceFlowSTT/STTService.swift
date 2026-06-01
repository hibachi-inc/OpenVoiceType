import Foundation
import Speech
import AVFAudio
import Accelerate
import VoiceFlowProtocol
import CoreMedia
import os

private let sttLogger = Logger(subsystem: "com.hibachi.voiceflow.stt", category: "STTService")

final class STTService: NSObject, STTServiceProtocol {
    private var recognizer: SFSpeechRecognizer?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()

    @available(macOS 26, *)
    private var analyzer: SpeechAnalyzer? {
        get { _analyzer as? SpeechAnalyzer }
        set { _analyzer = newValue }
    }
    private var _analyzer: AnyObject?
    private var analyzerTask: Task<Void, Never>?
    private var _analyzerContinuation: Any?
    @available(macOS 26, *)
    private var analyzerContinuation: AsyncStream<AnalyzerInput>.Continuation? {
        get { _analyzerContinuation as? AsyncStream<AnalyzerInput>.Continuation }
        set { _analyzerContinuation = newValue }
    }

    private var confirmedText = ""
    private var provisionalText = ""
    private var stopped = false
    private let lock = NSLock()

    private weak var connection: NSXPCConnection?
    private var tapInstalled = false

    init(connection: NSXPCConnection) {
        self.connection = connection
    }

    private var client: STTClientProtocol? {
        connection?.remoteObjectProxy as? STTClientProtocol
    }

    func startRecording(locale localeID: String, engine: String) {
        if recognitionTask != nil || _analyzer != nil {
            cleanup()
        }

        if engine == "enhanced", #available(macOS 26, *) {
            startWithSpeechAnalyzer(locale: localeID)
            return
        }

        startWithClassic(locale: localeID)
    }

    // MARK: - Classic (SFSpeechRecognizer)

    private func startWithClassic(locale localeID: String) {
        client?.didChangeEngine?("classic")
        let locale = Locale(identifier: localeID)
        guard let recognizer = SFSpeechRecognizer(locale: locale),
              recognizer.isAvailable else {
            client?.didEncounterError("Speech recognizer is not available for \(localeID).")
            return
        }
        self.recognizer = recognizer

        lock.lock()
        confirmedText = ""
        provisionalText = ""
        stopped = false
        lock.unlock()

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        if recognizer.supportsOnDeviceRecognition {
            request.requiresOnDeviceRecognition = true
        }
        if #available(macOS 26, *) {
            request.addsPunctuation = true
        }
        self.recognitionRequest = request

        installTapIfNeeded { [weak self] buffer in
            self?.recognitionRequest?.append(buffer)
        }

        recognitionTask = recognizer.recognitionTask(with: request) { [weak self] result, error in
            guard let self else { return }

            self.lock.lock()
            guard !self.stopped else { self.lock.unlock(); return }

            if let result {
                let text = result.bestTranscription.formattedString

                let threshold = max(self.provisionalText.count / 2, 1)
                if !self.provisionalText.isEmpty && text.count < threshold {
                    self.confirmedText = self.lockedFullTranscript
                }
                self.provisionalText = text
                let display = self.lockedFullTranscript
                self.lock.unlock()

                self.client?.didUpdateTranscript(display)

                if result.isFinal {
                    self.lock.lock()
                    self.confirmedText = self.lockedFullTranscript
                    self.provisionalText = ""
                    self.lock.unlock()
                }
                return
            }
            self.lock.unlock()

            if let error {
                let code = (error as NSError).code
                if code == 216 || code == 203 || code == 1110 {
                    self.lock.lock()
                    if !self.provisionalText.isEmpty {
                        self.confirmedText = self.lockedFullTranscript
                        self.provisionalText = ""
                    }
                    self.lock.unlock()
                } else {
                    self.client?.didEncounterError(error.localizedDescription)
                }
            }
        }

        do {
            audioEngine.prepare()
            try audioEngine.start()
        } catch {
            cleanup()
            client?.didEncounterError(error.localizedDescription)
        }
    }

    // MARK: - Enhanced (SpeechAnalyzer + SpeechTranscriber, macOS 26+)

    @available(macOS 26, *)
    private func startWithSpeechAnalyzer(locale localeID: String) {
        let locale = Locale(identifier: localeID)
        let transcriber = SpeechTranscriber(locale: locale, preset: .progressiveTranscription)

        // SAFETY: STTService lives in an XPC service; startRecording/stopRecording are serialized by XPC.
        // Mutable state (confirmedText, provisionalText, stopped) is protected by `lock`.
        nonisolated(unsafe) let unsafeSelf = self
        Task {
            let bcp47 = locale.identifier(.bcp47)
            let supported = await SpeechTranscriber.supportedLocales
            guard supported.contains(where: { $0.identifier(.bcp47) == bcp47 }) else {
                sttLogger.notice("[STTService] locale=\(bcp47, privacy: .public) not supported, falling back to classic")
                unsafeSelf.startWithClassic(locale: localeID)
                return
            }
            let installed = await SpeechTranscriber.installedLocales
            let isInstalled = installed.contains { $0.identifier(.bcp47) == bcp47 }
            sttLogger.notice("[STTService] locale=\(bcp47, privacy: .public) installed=\(isInstalled)")
            if isInstalled {
                unsafeSelf.launchAnalyzer(transcriber: transcriber, locale: localeID)
                return
            }
            sttLogger.notice("[STTService] Model not installed, falling back to classic")
            unsafeSelf.startWithClassic(locale: localeID)
        }
    }

    @available(macOS 26, *)
    private func launchAnalyzer(transcriber: SpeechTranscriber, locale localeID: String) {
        client?.didChangeEngine?("enhanced")
        lock.lock()
        confirmedText = ""
        provisionalText = ""
        stopped = false
        lock.unlock()

        let sa = SpeechAnalyzer(modules: [transcriber])
        self.analyzer = sa

        let inputNode = audioEngine.inputNode
        let micFormat = inputNode.outputFormat(forBus: 0)

        nonisolated(unsafe) let unsafeSelf = self
        analyzerTask = Task {
            var resultsTask: Task<Void, Error>?
            do {
                guard let analyzerFormat = await SpeechAnalyzer.bestAvailableAudioFormat(compatibleWith: [transcriber]) else {
                    sttLogger.notice("[STTService] No compatible audio format, falling back to classic")
                    unsafeSelf.startWithClassic(locale: localeID)
                    return
                }
                sttLogger.notice("[STTService] format: mic=\(micFormat, privacy: .public) analyzer=\(analyzerFormat, privacy: .public)")
                let converter: AVAudioConverter?
                if micFormat != analyzerFormat {
                    guard let c = AVAudioConverter(from: micFormat, to: analyzerFormat) else {
                        sttLogger.notice("[STTService] Cannot create converter, falling back to classic")
                        unsafeSelf.startWithClassic(locale: localeID)
                        return
                    }
                    c.primeMethod = .none
                    converter = c
                } else {
                    converter = nil
                }

                let (inputStream, continuation) = AsyncStream<AnalyzerInput>.makeStream()
                unsafeSelf.analyzerContinuation = continuation

                unsafeSelf.installTapIfNeeded { buffer in
                    if let converter {
                        let ratio = analyzerFormat.sampleRate / micFormat.sampleRate
                        let capacity = AVAudioFrameCount((Double(buffer.frameLength) * ratio).rounded(.up))
                        guard let converted = AVAudioPCMBuffer(pcmFormat: analyzerFormat, frameCapacity: capacity) else { return }
                        var error: NSError?
                        converter.convert(to: converted, error: &error) { _, outStatus in
                            outStatus.pointee = .haveData
                            return buffer
                        }
                        if error == nil {
                            continuation.yield(AnalyzerInput(buffer: converted))
                        }
                    } else {
                        continuation.yield(AnalyzerInput(buffer: buffer))
                    }
                }

                unsafeSelf.audioEngine.prepare()
                try unsafeSelf.audioEngine.start()
                sttLogger.notice("[STTService] enhanced engine started")

                resultsTask = Task {
                    for try await result in transcriber.results {
                        let shouldBreak = unsafeSelf.lock.withLock {
                            guard !unsafeSelf.stopped else { return true }
                            let text = String(result.text.characters)
                            let isFinal = result.isFinal
                            if isFinal {
                                sttLogger.notice("[STTService] final: \(text, privacy: .public)")
                                if unsafeSelf.confirmedText.isEmpty {
                                    unsafeSelf.confirmedText = text
                                } else {
                                    unsafeSelf.confirmedText += " " + text
                                }
                                unsafeSelf.provisionalText = ""
                            } else {
                                unsafeSelf.provisionalText = text
                            }
                            return false
                        }
                        if shouldBreak { break }
                        let display = unsafeSelf.lock.withLock { unsafeSelf.lockedFullTranscript }
                        unsafeSelf.client?.didUpdateTranscript(display)
                    }
                }

                try await sa.start(inputSequence: inputStream)
                try await resultsTask?.value
            } catch {
                resultsTask?.cancel()
                sttLogger.notice("[STTService] SpeechAnalyzer error: \(error), falling back to classic")
                let isStopped = unsafeSelf.lock.withLock {
                    guard !unsafeSelf.stopped else { return true }
                    unsafeSelf.confirmedText = unsafeSelf.lockedFullTranscript
                    unsafeSelf.provisionalText = ""
                    return false
                }
                if !isStopped {
                    unsafeSelf.cleanup()
                    unsafeSelf._analyzer = nil
                    unsafeSelf.startWithClassic(locale: localeID)
                }
            }
        }
    }

    // MARK: - Stop

    func stopRecording(reply: @escaping (String?) -> Void) {
        lock.lock()
        stopped = true
        let result = lockedFullTranscript
        confirmedText = ""
        provisionalText = ""
        lock.unlock()

        if #available(macOS 26, *), let sa = analyzer {
            analyzerContinuation?.finish()
            analyzerContinuation = nil
            analyzerTask?.cancel()
            analyzerTask = nil
            Task {
                try? await sa.finish(after: .zero)
            }
            self.analyzer = nil
        }

        recognitionRequest?.endAudio()
        recognitionTask?.finish()
        cleanup()

        reply(result.isEmpty ? nil : result)
    }

    // MARK: - Private

    private var audioTapHandler: ((AVAudioPCMBuffer) -> Void)?

    private func installTapIfNeeded(handler: @escaping (AVAudioPCMBuffer) -> Void) {
        audioTapHandler = handler
        let alreadyInstalled = lock.withLock { tapInstalled }
        guard !alreadyInstalled else { return }
        let inputNode = audioEngine.inputNode
        let format = inputNode.outputFormat(forBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, _ in
            self?.audioTapHandler?(buffer)
            self?.processAudioLevel(buffer: buffer)
        }
        lock.withLock { tapInstalled = true }
    }

    private func cleanup() {
        lock.lock()
        let shouldRemoveTap = tapInstalled
        tapInstalled = false
        lock.unlock()

        if shouldRemoveTap {
            audioEngine.inputNode.removeTap(onBus: 0)
        }
        audioTapHandler = nil
        audioEngine.stop()
        recognitionRequest = nil
        recognitionTask = nil
        recognizer = nil
    }

    /// Must be called while lock is held.
    private var lockedFullTranscript: String {
        if confirmedText.isEmpty { return provisionalText }
        if provisionalText.isEmpty { return confirmedText }
        return confirmedText + " " + provisionalText
    }

    private func processAudioLevel(buffer: AVAudioPCMBuffer) {
        guard let channelData = buffer.floatChannelData?[0] else { return }
        let frameLength = UInt(buffer.frameLength)
        var rms: Float = 0
        vDSP_rmsqv(channelData, 1, &rms, frameLength)
        let level = max(0, min(1, rms * 10))
        client?.didUpdateAudioLevel(level)
    }
}
