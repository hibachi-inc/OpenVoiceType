import Foundation
import SwiftUI

@MainActor
@Observable
final class PreferencesStore {
    static let shared = PreferencesStore()

    var hotkeyModifier: HotkeyModifier {
        didSet { defaults.set(hotkeyModifier.rawValue, forKey: "hotkeyModifier") }
    }
    var hotkeyKey: HotkeyKey {
        didSet { defaults.set(hotkeyKey.rawValue, forKey: "hotkeyKey") }
    }
    var locale: String {
        didSet { defaults.set(locale, forKey: "locale") }
    }
    var refinementMode: RefinementMode {
        didSet { defaults.set(refinementMode.rawValue, forKey: "refinementMode") }
    }
    var sttEngine: STTEngine {
        didSet { defaults.set(sttEngine.rawValue, forKey: "sttEngine") }
    }
    var launchAtLogin: Bool {
        didSet { defaults.set(launchAtLogin, forKey: "launchAtLogin") }
    }
    var appLanguage: String {
        didSet {
            if appLanguage == "system" {
                defaults.removeObject(forKey: "AppleLanguages")
                defaults.removeObject(forKey: "appLanguageUserSet")
            } else {
                defaults.set([appLanguage], forKey: "AppleLanguages")
                defaults.set(true, forKey: "appLanguageUserSet")
            }
        }
    }

    var defaultPrompt: String {
        didSet { defaults.set(defaultPrompt, forKey: "defaultPrompt") }
    }

    var isDefaultPromptCustomized: Bool {
        defaultPrompt != Self.localizedDefaultPrompt
    }

    #if PROFEATURES
    var appPrompts: [String: String] {
        didSet { defaults.set(appPrompts, forKey: "appPrompts") }
    }
    #endif

    var useDirectPaste: Bool {
        didSet { defaults.set(useDirectPaste, forKey: "useDirectPaste") }
    }

    var muteOtherAudio: Bool {
        didSet { defaults.set(muteOtherAudio, forKey: "muteOtherAudio") }
    }

    var pushToTalk: Bool {
        didSet { defaults.set(pushToTalk, forKey: "pushToTalk") }
    }

    #if PROFEATURES
    var translationLanguages: [TranslationLanguage] {
        didSet { saveTranslationLanguages() }
    }
    #endif

    private let defaults = UserDefaults.standard

    private init() {
        hotkeyModifier = HotkeyModifier(rawValue: defaults.string(forKey: "hotkeyModifier") ?? "") ?? .control
        hotkeyKey = HotkeyKey(rawValue: defaults.string(forKey: "hotkeyKey") ?? "") ?? .v
        locale = defaults.string(forKey: "locale") ?? "system"
        refinementMode = RefinementMode(rawValue: defaults.string(forKey: "refinementMode") ?? "") ?? .off
        sttEngine = STTEngine(rawValue: defaults.string(forKey: "sttEngine") ?? "") ?? .enhanced
        launchAtLogin = defaults.bool(forKey: "launchAtLogin")
        if defaults.object(forKey: "appLanguageUserSet") != nil,
           let langs = defaults.array(forKey: "AppleLanguages") as? [String],
           let first = langs.first {
            appLanguage = first
        } else {
            appLanguage = "system"
        }
        if let storedDefaultPrompt = defaults.string(forKey: "defaultPrompt") {
            if Self.shouldMigrateDefaultPrompt(storedDefaultPrompt) {
                defaultPrompt = Self.localizedDefaultPrompt
                defaults.set(Self.localizedDefaultPrompt, forKey: "defaultPrompt")
            } else {
                defaultPrompt = storedDefaultPrompt
            }
        } else {
            defaultPrompt = Self.localizedDefaultPrompt
        }
        #if PROFEATURES
        appPrompts = (defaults.dictionary(forKey: "appPrompts") as? [String: String]) ?? [:]
        #endif
        #if DIRECT
        useDirectPaste = defaults.object(forKey: "useDirectPaste") as? Bool ?? true
        #else
        useDirectPaste = false
        #endif
        muteOtherAudio = defaults.bool(forKey: "muteOtherAudio")
        pushToTalk = defaults.bool(forKey: "pushToTalk")
        #if PROFEATURES
        translationLanguages = Self.loadTranslationLanguages(from: defaults)
        #endif
    }

    func resetDefaultPrompt() {
        defaultPrompt = Self.localizedDefaultPrompt
    }

    private static var localizedDefaultPrompt: String {
        Bundle.main.localizedString(
            forKey: "refinement.default_prompt.initial",
            value: "",
            table: nil
        )
    }

    private static func shouldMigrateDefaultPrompt(_ prompt: String) -> Bool {
        let legacyDefaults = [
            "音声入力のため、誤認識と思われる箇所は意味を汲み取って正しい言葉に修正してください。修正不要な場合はそのまま出力してください。",
            "音声入力の文字起こしを、意味を変えずに読みやすい文章へ整えてください。フィラー、言い直し、重複、話し言葉の揺れを削除し、句読点と必要な改行を自然に補ってください。数字・金額・日付・単位は文脈に合う表記へ整えてください。日常文では「100,000円」は「10万円」、「10,000」は「1万」のように読みやすくし、正確な桁数が重要な場合は数字表記を保ってください。誤認識と思われる語だけ文脈から修正し、固有名詞・専門用語・コード・URLは勝手に変えないでください。説明は不要で、整形後のテキストのみ返してください。",
            "以下の音声文字起こしを、意味を変えずに読みやすい文章へ整えて。フィラー、言い直し、重複を削除し、句読点を補い、数字・金額・日付・単位を文脈に合う表記に整えて。",
            "This is voice input. If there seem to be transcription errors, please understand the meaning and correct them. If no corrections are needed, please output it as is.",
            "Clean up this voice-input transcript into readable text without changing the meaning. Remove filler words, restarts, duplicated phrases, and spoken-language roughness. Add natural punctuation and line breaks where helpful. Format numbers, money, dates, and units in the most readable form for the context: for everyday prose, prefer compact forms like \"100K yen\" or \"10,000\" as appropriate; when exact digits matter, keep the numeric notation. Correct only likely transcription errors from context, and do not rewrite proper nouns, technical terms, code, or URLs. Return only the refined text with no explanation.",
            "Clean up the following voice transcript into readable text without changing the meaning. Remove filler words, restarts, and repetition. Add punctuation, and format numbers, money, dates, and units appropriately for the context.",
        ]
        return legacyDefaults.contains(prompt)
    }

    #if PROFEATURES
    private func saveTranslationLanguages() {
        let data = translationLanguages.map { [
            "code": $0.code, "label": $0.label,
            "modifier": $0.modifier.rawValue, "key": $0.key.rawValue
        ] }
        defaults.set(data, forKey: "translationLanguages")
    }

    private static func loadTranslationLanguages(from defaults: UserDefaults) -> [TranslationLanguage] {
        guard let data = defaults.array(forKey: "translationLanguages") as? [[String: String]] else {
            return [
                TranslationLanguage(code: "en", label: "English", modifier: .control, key: .e),
                TranslationLanguage(code: "ja", label: "Japanese", modifier: .control, key: .j),
            ]
        }
        return data.compactMap { dict in
            guard let code = dict["code"], let label = dict["label"],
                  let mod = HotkeyModifier(rawValue: dict["modifier"] ?? ""),
                  let key = HotkeyKey(rawValue: dict["key"] ?? "") else { return nil }
            return TranslationLanguage(code: code, label: label, modifier: mod, key: key)
        }
    }
    #endif
}

// MARK: - Hotkey

enum HotkeyModifier: String, CaseIterable, Identifiable {
    case option = "option"
    case control = "control"
    case command = "command"

    var id: String { rawValue }
    var label: String {
        switch self {
        case .option: "⌥ Option"
        case .control: "⌃ Control"
        case .command: "⌘ Command"
        }
    }
    var symbol: String {
        switch self {
        case .option: "⌥"
        case .control: "⌃"
        case .command: "⌘"
        }
    }
    var eventModifier: NSEvent.ModifierFlags {
        switch self {
        case .option: .option
        case .control: .control
        case .command: .command
        }
    }
}

enum HotkeyKey: String, CaseIterable, Identifiable {
    case space = "space"
    case a = "a", b = "b", c = "c", d = "d", e = "e", f = "f"
    case g = "g", h = "h", i = "i", j = "j", k = "k", l = "l"
    case m = "m", n = "n", o = "o", p = "p", q = "q", r = "r"
    case s = "s", t = "t", u = "u", v = "v", w = "w", x = "x"
    case y = "y", z = "z"

    var id: String { rawValue }

    var label: String {
        self == .space ? "Space" : rawValue.uppercased()
    }

    var keyCode: UInt16 {
        switch self {
        case .space: 49
        case .a: 0; case .b: 11; case .c: 8; case .d: 2; case .e: 14; case .f: 3
        case .g: 5; case .h: 4; case .i: 34; case .j: 38; case .k: 40; case .l: 37
        case .m: 46; case .n: 45; case .o: 31; case .p: 35; case .q: 12; case .r: 15
        case .s: 1; case .t: 17; case .u: 32; case .v: 9; case .w: 13; case .x: 7
        case .y: 16; case .z: 6
        }
    }

    static func from(keyCode: UInt16) -> HotkeyKey? {
        allCases.first { $0.keyCode == keyCode }
    }
}

// MARK: - STT Engine

enum STTEngine: String, CaseIterable, Identifiable {
    case enhanced = "enhanced"
    case classic = "classic"

    var id: String { rawValue }
}

// MARK: - Refinement Mode

enum RefinementMode: String, CaseIterable, Identifiable {
    case off = "off"
    case refine = "refine"

    var id: String { rawValue }

    var label: String {
        switch self {
        case .off: String(localized: "refinement.off")
        #if PROFEATURES
        case .refine: String(localized: "refinement.refine_pro")
        #else
        case .refine: String(localized: "refinement.refine")
        #endif
        }
    }
    var description: String {
        switch self {
        case .off: String(localized: "refinement.off_desc")
        #if PROFEATURES
        case .refine: String(localized: "refinement.refine_pro_desc")
        #else
        case .refine: String(localized: "refinement.refine_desc")
        #endif
        }
    }
}

#if PROFEATURES
struct TranslationLanguage: Identifiable, Equatable {
    let id: UUID
    var code: String
    var label: String
    var modifier: HotkeyModifier
    var key: HotkeyKey

    init(code: String, label: String, modifier: HotkeyModifier, key: HotkeyKey) {
        self.id = UUID()
        self.code = code
        self.label = label
        self.modifier = modifier
        self.key = key
    }
}

enum AvailableLanguage: String, CaseIterable, Identifiable {
    case english = "en", japanese = "ja", chinese = "zh-Hans"
    case korean = "ko", german = "de", french = "fr"
    case spanish = "es", portuguese = "pt", italian = "it", russian = "ru"

    var id: String { rawValue }
    var label: String {
        switch self {
        case .english: "English"; case .japanese: "Japanese"; case .chinese: "Chinese"
        case .korean: "Korean"; case .german: "German"; case .french: "French"
        case .spanish: "Spanish"; case .portuguese: "Portuguese"
        case .italian: "Italian"; case .russian: "Russian"
        }
    }
    var defaultKey: HotkeyKey {
        switch self {
        case .english: .e; case .japanese: .j; case .chinese: .c
        case .korean: .k; case .german: .g; case .french: .f
        case .spanish: .s; case .portuguese: .p; case .italian: .i; case .russian: .r
        }
    }
}
#endif
