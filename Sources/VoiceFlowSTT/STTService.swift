import Foundation
import Speech
import AVFAudio
import Accelerate
import VoiceFlowProtocol

final class STTService: NSObject, STTServiceProtocol {
    private var recognizer: SFSpeechRecognizer?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()

    // All access to these 3 fields must be inside lock
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

    func startRecording(locale localeID: String) {
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

        if !tapInstalled {
            let inputNode = audioEngine.inputNode
            let format = inputNode.outputFormat(forBus: 0)
            inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, _ in
                self?.recognitionRequest?.append(buffer)
                self?.processAudioLevel(buffer: buffer)
            }
            tapInstalled = true
        }

        recognitionTask = recognizer.recognitionTask(with: request) { [weak self] result, error in
            guard let self else { return }

            self.lock.lock()
            guard !self.stopped else { self.lock.unlock(); return }

            if let result {
                let text = result.bestTranscription.formattedString

                // Detect segment reset: new text is much shorter than previous.
                // Use max(provisionalText.count / 2, 1) to handle short texts too.
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

    func stopRecording(reply: @escaping (String?) -> Void) {
        // Stop accepting callbacks immediately
        lock.lock()
        stopped = true
        let result = lockedFullTranscript
        confirmedText = ""
        provisionalText = ""
        lock.unlock()

        // Clean up audio and recognition
        recognitionRequest?.endAudio()
        recognitionTask?.finish()
        cleanup()

        reply(result.isEmpty ? nil : result)
    }

    private func cleanup() {
        if tapInstalled {
            audioEngine.inputNode.removeTap(onBus: 0)
            tapInstalled = false
        }
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
