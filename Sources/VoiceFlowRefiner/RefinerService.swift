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
            let sanitized = sanitizeOutput(refined, original: text)
            logger.info("Refined: \(refined.prefix(50))...")
            return sanitized.isEmpty ? text : sanitized
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
        return """
        \(prompt)

        "\(text)"
        """
    }

    private static func jaRules(for category: String) -> String {
        let hint: String
        switch category {
        case "chat", "email", "browser", "notes": hint = ""
        case "code": hint = "コードエディタ向け: 技術用語・識別子をそのまま保持。"
        case "terminal": hint = "ターミナル向け: コマンド・フラグ・パスをそのまま保持。"
        default: hint = ""
        }
        return """
        以下の音声文字起こしを整形して。言い換え、要約、補足、文体変更、語順変更、推測による修正はしないで。フィラーを削除し、句読点を補い、数字・金額・日付・単位を文脈に合う表記へ整えるだけにして。\(hint)
        整形後の本文だけを返して。
        """
    }

    private static func enRules(for category: String) -> String {
        let hint: String
        switch category {
        case "chat", "email", "browser", "notes": hint = ""
        case "code": hint = "For a code editor. Preserve identifiers and symbols exactly."
        case "terminal": hint = "For terminal. Preserve commands and flags exactly."
        default: hint = ""
        }
        return """
        Format the following voice transcript only. Do not paraphrase, summarize, add details, change tone, reorder wording, or make inferred corrections. Only remove filler words, add punctuation, and format numbers, money, dates, and units appropriately for the context. \(hint)
        Return only the refined text.
        """
    }

    private static func sanitizeOutput(_ output: String, original: String) -> String {
        let trimmed = output.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return trimmed }

        let lower = trimmed.lowercased()
        let originalLower = original.lowercased()
        let leakedInputTag = lower.contains("<input>") && !originalLower.contains("<input>")
        let looksLikeExplanation = [
            "テキストは以下の通り",
            "以下の通りです",
            "機能です",
            "デフォルト指示",
            "the text is as follows",
            "the transcript is as follows",
        ].contains { lower.contains($0) }

        if leakedInputTag || looksLikeExplanation {
            logger.warning("Model returned prompt/meta text; falling back to simple cleanup")
            return SimpleRefiner.clean(original)
        }

        return trimmed
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
