import Foundation

@objc public protocol STTServiceProtocol {
    func startRecording(locale: String, engine: String)
    func stopRecording(reply: @escaping (String?) -> Void)
}

@objc public protocol STTClientProtocol {
    func didUpdateTranscript(_ text: String)
    func didUpdateAudioLevel(_ level: Float)
    func didEncounterError(_ description: String)
    @objc optional func didChangeEngine(_ engine: String)
}

public enum STTXPCConstants {
    #if PROFEATURES
    public static let serviceName = "com.hibachi.koeri.stt"
    #else
    public static let serviceName = "com.hibachi.voiceflow.stt"
    #endif
}
