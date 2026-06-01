import Foundation

@objc public protocol RefinerServiceProtocol {
    func refine(text: String, category: String, reply: @escaping (String?) -> Void)
    func translate(text: String, targetLanguage: String, reply: @escaping (String?) -> Void)
}

public enum RefinerXPCConstants {
    public static let serviceName = "com.hibachi.voiceflow.refiner"
}
