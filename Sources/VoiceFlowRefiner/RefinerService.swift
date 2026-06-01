import Foundation
import NaturalLanguage
import VoiceFlowProtocol

/// SimpleRefiner: lightweight text cleanup without AI.
/// Removes filler words and normalizes whitespace.
/// The Pro version replaces this with FoundationModels-powered refinement.
final class RefinerService: NSObject, RefinerServiceProtocol, @unchecked Sendable {
    func refine(text: String, category: String, reply: @escaping (String?) -> Void) {
        reply(SimpleRefiner.clean(text))
    }

    func translate(text: String, targetLanguage: String, reply: @escaping (String?) -> Void) {
        reply(text)
    }
}

enum SimpleRefiner {
    // Compiled once, reused across calls
    private static let enFillerRegex: NSRegularExpression? = try? NSRegularExpression(
        pattern: #"\b(um|uh|like|you know|I mean|so|well|basically|actually|literally)\b"#,
        options: .caseInsensitive
    )

    // Japanese fillers — only match standalone (surrounded by whitespace, punctuation, or string boundaries)
    // Longer forms first to avoid partial matches
    private static let jaFillerRegex: NSRegularExpression? = try? NSRegularExpression(
        pattern: #"(?:^|(?<=[\s、。，．！？!?\n]))(?:えーっと|えーと|えっと|あのー|まあ|えー|なんか)(?=$|[\s、。，．！？!?\n])"#,
        options: []
    )

    static func clean(_ text: String) -> String {
        var result = text

        let lang = detectLanguage(text)
        let regex = lang == "ja" ? jaFillerRegex : enFillerRegex

        if let regex {
            result = regex.stringByReplacingMatches(
                in: result,
                range: NSRange(result.startIndex..., in: result),
                withTemplate: ""
            )
        }

        result = result.replacingOccurrences(of: "  +", with: " ", options: .regularExpression)
        result = result.trimmingCharacters(in: .whitespacesAndNewlines)

        return result.isEmpty ? text : result
    }

    private static func detectLanguage(_ text: String) -> String {
        let recognizer = NLLanguageRecognizer()
        recognizer.processString(text)
        return recognizer.dominantLanguage?.rawValue ?? "en"
    }
}
