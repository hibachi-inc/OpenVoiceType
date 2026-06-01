import Foundation
import os
import VoiceFlowProtocol

private let logger = Logger(subsystem: "com.hibachi.voiceflow", category: "RefinerXPCClient")

@MainActor
final class RefinerXPCClient: RefinerClientProtocol {
    var onError: ((String) -> Void)?

    private var connection: NSXPCConnection?
    private var connectionValid = false
    private let timeoutSeconds: TimeInterval = 5

    private func ensureConnection() -> NSXPCConnection {
        if let connection, connectionValid { return connection }

        disconnect()
        logger.info("Establishing XPC connection to Refiner service")

        let conn = NSXPCConnection(serviceName: RefinerXPCConstants.serviceName)
        conn.remoteObjectInterface = NSXPCInterface(with: RefinerServiceProtocol.self)

        conn.invalidationHandler = { [weak self] in
            logger.warning("Refiner XPC connection invalidated")
            Task { @MainActor in
                self?.connectionValid = false
                self?.connection = nil
            }
        }
        conn.interruptionHandler = { [weak self] in
            logger.warning("Refiner XPC connection interrupted")
            Task { @MainActor in
                self?.connectionValid = false
                self?.onError?("Refiner service interrupted.")
            }
        }

        conn.resume()
        self.connection = conn
        self.connectionValid = true
        return conn
    }

    private var service: RefinerServiceProtocol? {
        let conn = ensureConnection()
        return conn.remoteObjectProxyWithErrorHandler { error in
            logger.error("Refiner XPC proxy error: \(error.localizedDescription)")
            Task { @MainActor in self.onError?(error.localizedDescription) }
        } as? RefinerServiceProtocol
    }

    /// Returns (refinedText, didTimeout).
    func refine(text: String, category: String) async -> (String, Bool) {
        logger.info("Refining text (category: \(category), timeout: \(self.timeoutSeconds)s)")
        nonisolated(unsafe) let svc = self.service
        let result: (String, Bool) = await withXPCTimeout(
            seconds: timeoutSeconds,
            fallback: (text, true)
        ) { resume in
            guard let svc else {
                resume((text, true))
                return
            }
            svc.refine(text: text, category: category) { refined in
                resume((refined ?? text, false))
            }
        }
        if result.1 {
            logger.warning("Refiner timed out, returning raw text")
        }
        return result
    }

    #if PROFEATURES
    func translate(text: String, targetLanguage: String) async -> (String, Bool) {
        logger.info("Translating text to \(targetLanguage)")
        nonisolated(unsafe) let svc = self.service
        let result: (String, Bool) = await withXPCTimeout(
            seconds: timeoutSeconds,
            fallback: (text, true)
        ) { resume in
            guard let svc else {
                resume((text, true))
                return
            }
            svc.translate(text: text, targetLanguage: targetLanguage) { translated in
                resume((translated ?? text, false))
            }
        }
        if result.1 {
            logger.warning("Translation timed out, returning raw text")
        }
        return result
    }
    #endif

    func disconnect() {
        connectionValid = false
        connection?.invalidate()
        connection = nil
    }
}
