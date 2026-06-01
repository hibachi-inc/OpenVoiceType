import Foundation
import os
import VoiceFlowProtocol

private let logger = Logger(subsystem: "com.hibachi.voiceflow", category: "STTXPCClient")

/// Weak proxy to break the retain cycle: NSXPCConnection → exportedObject → STTXPCClient.
private class STTClientWeakProxy: NSObject, STTClientProtocol {
    weak var target: STTXPCClient?

    func didUpdateTranscript(_ text: String) { target?.didUpdateTranscript(text) }
    func didUpdateAudioLevel(_ level: Float) { target?.didUpdateAudioLevel(level) }
    func didEncounterError(_ description: String) { target?.didEncounterError(description) }
    func didChangeEngine(_ engine: String) { target?.didChangeEngine(engine) }
}

@MainActor
final class STTXPCClient: NSObject, STTClientProtocol, STTClientProtocol_App {
    var onTranscript: ((String) -> Void)?
    var onAudioLevel: ((Float) -> Void)?
    var onError: ((String) -> Void)?
    var onEngineChanged: ((String) -> Void)?
    var onConnectionInvalidated: (() -> Void)?

    private var connection: NSXPCConnection?
    private var connectionValid = false
    private let stopTimeoutSeconds: TimeInterval = 10

    private func ensureConnection() -> NSXPCConnection {
        if let connection, connectionValid { return connection }

        disconnect()
        logger.info("Establishing XPC connection to STT service")

        let conn = NSXPCConnection(serviceName: STTXPCConstants.serviceName)
        conn.remoteObjectInterface = NSXPCInterface(with: STTServiceProtocol.self)
        conn.exportedInterface = NSXPCInterface(with: STTClientProtocol.self)

        let proxy = STTClientWeakProxy()
        proxy.target = self
        conn.exportedObject = proxy

        conn.invalidationHandler = { [weak self] in
            logger.warning("STT XPC connection invalidated")
            Task { @MainActor in
                self?.connectionValid = false
                self?.connection = nil
                self?.onConnectionInvalidated?()
            }
        }
        conn.interruptionHandler = { [weak self] in
            logger.warning("STT XPC connection interrupted")
            Task { @MainActor in
                self?.connectionValid = false
                self?.onError?("Speech service interrupted. Reconnecting...")
            }
        }

        conn.resume()
        self.connection = conn
        self.connectionValid = true
        return conn
    }

    private var service: STTServiceProtocol? {
        let conn = ensureConnection()
        return conn.remoteObjectProxyWithErrorHandler { error in
            logger.error("STT XPC proxy error: \(error.localizedDescription)")
            Task { @MainActor in self.onError?(error.localizedDescription) }
        } as? STTServiceProtocol
    }

    func startRecording(locale: String, engine: String = "enhanced") {
        logger.info("Starting recording with locale: \(locale), engine: \(engine)")
        service?.startRecording(locale: locale, engine: engine)
    }

    func stopRecording() async -> String? {
        logger.info("Stopping recording (timeout: \(self.stopTimeoutSeconds)s)")
        nonisolated(unsafe) let svc = self.service
        return await withXPCTimeout(seconds: stopTimeoutSeconds, fallback: nil) { resume in
            guard let svc else {
                resume(nil)
                return
            }
            svc.stopRecording { transcript in
                resume(transcript)
            }
        }
    }

    func disconnect() {
        connectionValid = false
        connection?.invalidate()
        connection = nil
    }

    // MARK: - STTClientProtocol (callbacks from XPC service)

    nonisolated func didUpdateTranscript(_ text: String) {
        Task { @MainActor in self.onTranscript?(text) }
    }

    nonisolated func didUpdateAudioLevel(_ level: Float) {
        Task { @MainActor in self.onAudioLevel?(level) }
    }

    nonisolated func didEncounterError(_ description: String) {
        logger.error("STT service error: \(description)")
        Task { @MainActor in self.onError?(description) }
    }

    nonisolated func didChangeEngine(_ engine: String) {
        logger.info("STT engine changed to: \(engine)")
        Task { @MainActor in self.onEngineChanged?(engine) }
    }
}
