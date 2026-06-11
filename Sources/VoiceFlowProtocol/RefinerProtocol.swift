import Foundation

@objc public protocol RefinerServiceProtocol {
    func refine(text: String, context: [String: String], reply: @escaping (String?) -> Void)
    func translate(text: String, targetLanguage: String, reply: @escaping (String?) -> Void)
}

public enum RefinerContextKey {
    public static let category = "category"
    public static let appName = "appName"
    public static let bundleID = "bundleID"
    public static let customPrompt = "customPrompt"
    public static let beforeText = "beforeText"
    public static let afterText = "afterText"
}

public enum RefinerXPCConstants {
    #if PROFEATURES
    public static let serviceName = "com.hibachi.voicelatte.refiner"
    #else
    public static let serviceName = "com.hibachi.voiceflow.refiner"
    #endif
}
