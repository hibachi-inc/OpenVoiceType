import Foundation
import NaturalLanguage
import os
import VoiceFlowProtocol

#if canImport(FoundationModels)
import FoundationModels
#endif

private let logger = Logger(subsystem: "com.hibachi.voiceflow.refiner", category: "Refiner")

final class RefinerService: NSObject, RefinerServiceProtocol, @unchecked Sendable {
    func refine(text: String, context: [String: String], reply: @escaping (String?) -> Void) {
        #if canImport(FoundationModels)
        if #available(macOS 26, *) {
            nonisolated(unsafe) let sendableReply = reply
            Task {
                let refined = await FoundationModelsRefiner.refine(text: text, context: context)
                sendableReply(refined)
            }
            return
        }
        #endif
        reply(SimpleRefiner.clean(text))
    }

    func translate(text: String, targetLanguage: String, reply: @escaping (String?) -> Void) {
        reply(text)
    }
}

// MARK: - FoundationModels AI Refinement (macOS 26+)

#if canImport(FoundationModels)
@available(macOS 26, *)
enum FoundationModelsRefiner {
    static func refine(text: String, context: [String: String]) async -> String {
        let model = SystemLanguageModel(
            guardrails: .permissiveContentTransformations
        )
        guard model.availability == .available else {
            logger.warning("FoundationModels not available, falling back to SimpleRefiner")
            return SimpleRefiner.clean(text)
        }

        let category = context[RefinerContextKey.category] ?? "generic"
        let customPrompt = context[RefinerContextKey.customPrompt]
        let lang = SimpleRefiner.detectLanguage(text)
        let taskPrompt = buildPrompt(for: text, category: category, language: lang, customPrompt: customPrompt)
        let session = LanguageModelSession(model: model)

        do {
            let response = try await session.respond(to: taskPrompt)
            let refined = response.content.trimmingCharacters(in: .whitespacesAndNewlines)
            logger.info("Refined: \(refined.prefix(50))...")
            return refined.isEmpty ? text : refined
        } catch {
            logger.error("Refine error: \(error.localizedDescription)")
            return SimpleRefiner.clean(text)
        }
    }

    private static func buildPrompt(for text: String, category: String, language: String, customPrompt: String?) -> String {
        let rules = language == "ja" ? jaRules(for: category) : enRules(for: category)
        var prompt = rules
        if let customPrompt, !customPrompt.isEmpty {
            prompt += "\n[USER INSTRUCTION] \(customPrompt)"
        }
        let escaped = text.replacingOccurrences(of: "\"", with: "'")
        return "\(prompt)\n\n[INPUT] \"\(escaped)\""
    }

    private static func jaRules(for category: String) -> String {
        let hint: String
        switch category {
        case "chat": hint = "チャット向け: 簡潔で会話的な文体。"
        case "email": hint = "メール向け: 丁寧で完全な文章。"
        case "code": hint = "コードエディタ向け: 技術用語・識別子をそのまま保持。"
        case "terminal": hint = "ターミナル向け: コマンド・フラグ・パスをそのまま保持。"
        case "notes": hint = "ノート向け: 箇条書きで構造化。"
        case "browser": hint = "ブラウザ向け: 簡潔な文体。"
        default: hint = "自然な日本語に整形。"
        }
        return """
        [TASK] 以下の音声入力テキストを整形してください。\(hint)
        フィラー（えーと、あの、まあ）を削除し、句読点を追加し、誤認識を文脈から修正してください。
        意味を変えないでください。整形後のテキストのみを返してください。説明や挨拶や前置きは絶対に不要です。
        """
    }

    private static func enRules(for category: String) -> String {
        let hint: String
        switch category {
        case "chat": hint = "For a chat app. Keep concise and conversational."
        case "email": hint = "For email. Use polished, complete sentences."
        case "code": hint = "For a code editor. Preserve identifiers and symbols exactly."
        case "terminal": hint = "For terminal. Preserve commands and flags exactly."
        case "notes": hint = "For notes. Structure with bullet points."
        case "browser": hint = "For browser. Concise for forms and comments."
        default: hint = "Produce natural, well-formatted text."
        }
        return """
        [TASK] Refine the following voice-input text. \(hint)
        Remove filler words, add punctuation, fix misrecognitions from context.
        Do NOT change the meaning. Return ONLY the refined text. No explanations, no greetings, no preamble.
        """
    }
}
#endif

// MARK: - SimpleRefiner (Fallback)

enum SimpleRefiner {
    private static let enFillerRegex: NSRegularExpression? = try? NSRegularExpression(
        pattern: #"\b(um|uh|like|you know|I mean|so|well|basically|actually|literally)\b"#,
        options: .caseInsensitive
    )

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

    static func detectLanguage(_ text: String) -> String {
        let recognizer = NLLanguageRecognizer()
        recognizer.processString(text)
        return recognizer.dominantLanguage?.rawValue ?? "en"
    }
}
