import Foundation

@MainActor
protocol STTClientProtocol_App {
    var onTranscript: ((String) -> Void)? { get set }
    var onAudioLevel: ((Float) -> Void)? { get set }
    var onError: ((String) -> Void)? { get set }
    var onEngineChanged: ((String) -> Void)? { get set }
    var onConnectionInvalidated: (() -> Void)? { get set }

    func startRecording(locale: String, engine: String)
    func stopRecording() async -> String?
    func disconnect()
}

@MainActor
protocol RefinerClientProtocol {
    var onError: ((String) -> Void)? { get set }

    func refine(text: String, category: String) async -> (String, Bool)
    #if PROFEATURES
    func translate(text: String, targetLanguage: String) async -> (String, Bool)
    #endif
    func disconnect()
}

@MainActor
protocol HUDProtocol {
    var onTap: (() -> Void)? { get set }
    func showListening()
    func showProcessing(transcript: String)
    func showCopied(text: String)
    func showInserted(text: String)
    func showError(_ message: String)
    func updateTranscript(_ text: String)
    func updateAudioLevel(_ level: Float)
    func updateEngine(_ engine: String)
    func hide()
}
