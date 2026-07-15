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
    private var stopRequested = false
    private var stopReply: ((String?) -> Void)?
    private var stopFinalizationTask: Task<Void, Never>?
    private let lock = NSLock()

    private weak var connection: NSXPCConnection?
    private var tapInstalled = false
    private var pendingBuffers: [AVAudioPCMBuffer] = []

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

    private func startWithClassic(locale localeID: String, initialBuffers: [AVAudioPCMBuffer] = []) {
        client?.didChangeEngine?("classic")

        lock.lock()
        confirmedText = ""
        provisionalText = ""
        stopped = false
        stopRequested = false
        stopReply = nil
        stopFinalizationTask?.cancel()
        stopFinalizationTask = nil
        pendingBuffers = initialBuffers
        lock.unlock()

        // Start audio capture immediately — buffer while recognizer loads
        installTapIfNeeded { [weak self] buffer in
            guard let self else { return }
            self.lock.lock()
            if let request = self.recognitionRequest {
                self.lock.unlock()
                request.append(buffer)
            } else {
                if let copied = self.copyAudioBuffer(buffer) {
                    self.pendingBuffers.append(copied)
                }
                self.lock.unlock()
            }
        }
        do {
            audioEngine.prepare()
            try audioEngine.start()
        } catch {
            cleanup()
            client?.didEncounterError(error.localizedDescription)
            return
        }

        let locale = Locale(identifier: localeID)
        guard let recognizer = SFSpeechRecognizer(locale: locale),
              recognizer.isAvailable else {
            cleanup()
            client?.didEncounterError("Speech recognizer is not available for \(localeID).")
            return
        }
        self.recognizer = recognizer

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        if recognizer.supportsOnDeviceRecognition {
            request.requiresOnDeviceRecognition = true
        }
        if #available(macOS 26, *) {
            request.addsPunctuation = true
        }

        // Flush buffered audio, then switch to direct append
        lock.lock()
        for buffer in pendingBuffers { request.append(buffer) }
        pendingBuffers.removeAll()
        self.recognitionRequest = request
        lock.unlock()

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
                    let shouldCompleteStop = self.stopRequested
                    self.lock.unlock()
                    if shouldCompleteStop {
                        self.completeStop()
                    }
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
                    let shouldCompleteStop = self.stopRequested
                    self.lock.unlock()
                    if shouldCompleteStop {
                        self.completeStop()
                    }
                } else {
                    self.client?.didEncounterError(error.localizedDescription)
                    if self.lock.withLock({ self.stopRequested }) {
                        self.completeStop()
                    }
                }
            }
        }
    }

    // MARK: - Enhanced (SpeechAnalyzer + SpeechTranscriber, macOS 26+)

    @available(macOS 26, *)
    private func startWithSpeechAnalyzer(locale localeID: String) {
        let locale = Locale(identifier: localeID)
        let transcriber = SpeechTranscriber(locale: locale, preset: .progressiveTranscription)

        lock.lock()
        confirmedText = ""
        provisionalText = ""
        stopped = false
        stopRequested = false
        stopReply = nil
        stopFinalizationTask?.cancel()
        stopFinalizationTask = nil
        pendingBuffers.removeAll()
        lock.unlock()

        // Start audio capture immediately — buffer while checking model availability
        installTapIfNeeded { [weak self] buffer in
            guard let self else { return }
            self.lock.lock()
            if let copied = self.copyAudioBuffer(buffer) {
                self.pendingBuffers.append(copied)
            }
            self.lock.unlock()
        }
        do {
            audioEngine.prepare()
            try audioEngine.start()
        } catch {
            cleanup()
            client?.didEncounterError(error.localizedDescription)
            return
        }

        nonisolated(unsafe) let unsafeSelf = self
        Task {
            let bcp47 = locale.identifier(.bcp47)
            let supported = await SpeechTranscriber.supportedLocales
            guard supported.contains(where: { $0.identifier(.bcp47) == bcp47 }) else {
                sttLogger.notice("[STTService] locale=\(bcp47, privacy: .public) not supported, falling back to classic")
                unsafeSelf.fallbackToClassicPreservingBufferedAudio(locale: localeID)
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
            unsafeSelf.fallbackToClassicPreservingBufferedAudio(locale: localeID)
        }
    }

    @available(macOS 26, *)
    private func launchAnalyzer(transcriber: SpeechTranscriber, locale localeID: String) {
        client?.didChangeEngine?("enhanced")

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
                    unsafeSelf.fallbackToClassicPreservingBufferedAudio(locale: localeID)
                    return
                }
                sttLogger.notice("[STTService] format: mic=\(micFormat, privacy: .public) analyzer=\(analyzerFormat, privacy: .public)")
                let converter: AVAudioConverter?
                if micFormat != analyzerFormat {
                    guard let c = AVAudioConverter(from: micFormat, to: analyzerFormat) else {
                        sttLogger.notice("[STTService] Cannot create converter, falling back to classic")
                        unsafeSelf.fallbackToClassicPreservingBufferedAudio(locale: localeID)
                        return
                    }
                    c.primeMethod = .none
                    converter = c
                } else {
                    converter = nil
                }

                let (inputStream, continuation) = AsyncStream<AnalyzerInput>.makeStream()
                unsafeSelf.analyzerContinuation = continuation

                // Flush buffered audio, then switch tap to analyzer feed
                let convertAndYield: (AVAudioPCMBuffer) -> Void = { buffer in
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

                let buffered = unsafeSelf.lock.withLock {
                    let b = unsafeSelf.pendingBuffers
                    unsafeSelf.pendingBuffers.removeAll()
                    return b
                }
                for buffer in buffered { convertAndYield(buffer) }

                unsafeSelf.installTapIfNeeded { buffer in convertAndYield(buffer) }
                sttLogger.notice("[STTService] enhanced engine started, flushed buffered audio")

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
                                    unsafeSelf.confirmedText = Self.joinTranscriptParts(unsafeSelf.confirmedText, text)
                                }
                                unsafeSelf.provisionalText = ""
                            } else {
                                unsafeSelf.provisionalText = text
                            }
                            if isFinal && unsafeSelf.stopRequested {
                                return true
                            }
                            return false
                        }
                        let display = unsafeSelf.lock.withLock { unsafeSelf.lockedFullTranscript }
                        unsafeSelf.client?.didUpdateTranscript(display)
                        if shouldBreak {
                            unsafeSelf.completeStop()
                            break
                        }
                    }
                }

                try await sa.start(inputSequence: inputStream)
                try await resultsTask?.value
                if unsafeSelf.lock.withLock({ unsafeSelf.stopRequested }) {
                    unsafeSelf.completeStop()
                }
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
        var duplicateStopResult: String?
        let didRequestStop = lock.withLock {
            guard stopReply == nil else {
                duplicateStopResult = lockedFullTranscript
                return false
            }
            stopRequested = true
            stopReply = reply
            return true
        }

        guard didRequestStop else {
            let result = duplicateStopResult ?? ""
            reply(result.isEmpty ? nil : result)
            return
        }

        let shouldReplyImmediately = recognitionTask == nil && _analyzer == nil
        if shouldReplyImmediately {
            completeStop()
            return
        }

        stopAudioCapture()

        if #available(macOS 26, *), let sa = analyzer {
            analyzerContinuation?.finish()
            analyzerContinuation = nil
            Task {
                try? await sa.finish(after: .zero)
            }
        }

        recognitionRequest?.endAudio()
        recognitionTask?.finish()

        stopFinalizationTask?.cancel()
        nonisolated(unsafe) let unsafeSelf = self
        stopFinalizationTask = Task {
            try? await Task.sleep(for: .milliseconds(900))
            unsafeSelf.completeStop()
        }
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
        stopFinalizationTask?.cancel()
        stopFinalizationTask = nil
        if #available(macOS 26, *) {
            analyzerContinuation?.finish()
            analyzerContinuation = nil
            analyzerTask?.cancel()
            analyzerTask = nil
            analyzer = nil
        }
        lock.lock()
        let shouldRemoveTap = tapInstalled
        tapInstalled = false
        pendingBuffers.removeAll()
        recognitionRequest = nil
        lock.unlock()

        if shouldRemoveTap {
            audioEngine.inputNode.removeTap(onBus: 0)
        }
        audioTapHandler = nil
        audioEngine.stop()
        recognitionTask = nil
        recognizer = nil
    }

    private func stopAudioCapture() {
        let shouldRemoveTap = lock.withLock {
            let installed = tapInstalled
            tapInstalled = false
            pendingBuffers.removeAll()
            return installed
        }
        if shouldRemoveTap {
            audioEngine.inputNode.removeTap(onBus: 0)
        }
        audioTapHandler = nil
        audioEngine.stop()
    }

    private func completeStop() {
        let completion = lock.withLock { () -> (((String?) -> Void), String)? in
            guard let reply = stopReply else { return nil }
            let result = lockedFullTranscript
            stopped = true
            stopRequested = false
            stopReply = nil
            confirmedText = ""
            provisionalText = ""
            return (reply, result)
        }

        cleanup()

        guard let (reply, result) = completion else { return }
        reply(result.isEmpty ? nil : result)
    }

    /// Must be called while lock is held.
    private var lockedFullTranscript: String {
        if confirmedText.isEmpty { return provisionalText }
        if provisionalText.isEmpty { return confirmedText }
        return Self.joinTranscriptParts(confirmedText, provisionalText)
    }

    private static func joinTranscriptParts(_ left: String, _ right: String) -> String {
        guard !left.isEmpty else { return right }
        guard !right.isEmpty else { return left }
        guard let last = left.last, let first = right.first else { return left + right }

        if last.isWhitespace || first.isWhitespace || isJapanese(last) || isJapanese(first) {
            return left + right
        }
        return left + " " + right
    }

    private static func isJapanese(_ character: Character) -> Bool {
        character.unicodeScalars.contains { scalar in
            switch scalar.value {
            case 0x3040...0x30FF, 0x3400...0x4DBF, 0x4E00...0x9FFF:
                true
            default:
                false
            }
        }
    }

    private func processAudioLevel(buffer: AVAudioPCMBuffer) {
        guard let channelData = buffer.floatChannelData?[0] else { return }
        let frameLength = UInt(buffer.frameLength)
        var rms: Float = 0
        vDSP_rmsqv(channelData, 1, &rms, frameLength)
        let level = max(0, min(1, rms * 10))
        client?.didUpdateAudioLevel(level)
    }

    private func fallbackToClassicPreservingBufferedAudio(locale localeID: String) {
        let buffered = lock.withLock {
            let buffers = pendingBuffers
            pendingBuffers.removeAll()
            return buffers
        }
        cleanup()
        startWithClassic(locale: localeID, initialBuffers: buffered)
    }

    private func copyAudioBuffer(_ buffer: AVAudioPCMBuffer) -> AVAudioPCMBuffer? {
        guard let copied = AVAudioPCMBuffer(
            pcmFormat: buffer.format,
            frameCapacity: buffer.frameLength
        ) else {
            return nil
        }
        copied.frameLength = buffer.frameLength

        let sourceBuffers = UnsafeMutableAudioBufferListPointer(buffer.mutableAudioBufferList)
        let copiedBuffers = UnsafeMutableAudioBufferListPointer(copied.mutableAudioBufferList)
        for index in 0..<min(sourceBuffers.count, copiedBuffers.count) {
            guard let source = sourceBuffers[index].mData,
                  let destination = copiedBuffers[index].mData else {
                continue
            }
            let byteCount = Int(sourceBuffers[index].mDataByteSize)
            memcpy(destination, source, byteCount)
            copiedBuffers[index].mDataByteSize = sourceBuffers[index].mDataByteSize
        }

        return copied
    }
}
