import AppKit
import ApplicationServices
import os

private let axLogger = Logger(subsystem: "com.hibachi.voicelatte", category: "AppContext")

struct AppContext: Sendable {
    enum Category: String, CaseIterable, Sendable {
        case chat, email, code, terminal, notes, browser, generic
    }

    let appName: String
    let bundleIdentifier: String?
    let category: Category
    let siteDomain: String?
    let cursorBefore: String?
    let cursorAfter: String?

    /// Display key for prompt lookup: "gmail.com" for browser sites, "Safari" for browsers without domain, "Slack" for native apps.
    var promptKey: String {
        siteDomain ?? appName
    }

    /// Effective category: URL-based override for browser sites, otherwise app-based.
    var effectiveCategory: Category {
        if let domain = siteDomain {
            return Self.classifyByURL(domain) ?? category
        }
        return category
    }

    static var current: AppContext? {
        guard let app = NSWorkspace.shared.frontmostApplication,
              let appName = app.localizedName else { return nil }
        let category = classify(appName: appName, bundleID: app.bundleIdentifier)
        let domain = shouldCaptureSiteDomain(for: category) ? siteKey(pid: app.processIdentifier) : nil
        let cursor = cursorContext(pid: app.processIdentifier)
        return AppContext(
            appName: appName,
            bundleIdentifier: app.bundleIdentifier,
            category: category,
            siteDomain: domain,
            cursorBefore: cursor.before,
            cursorAfter: cursor.after
        )
    }

    static func forTesting(appName: String, bundleID: String?, siteDomain: String? = nil) -> AppContext {
        AppContext(
            appName: appName,
            bundleIdentifier: bundleID,
            category: classify(appName: appName, bundleID: bundleID),
            siteDomain: siteDomain,
            cursorBefore: nil,
            cursorAfter: nil
        )
    }

    static func shouldCaptureSiteDomainForTesting(appName: String, bundleID: String?) -> Bool {
        shouldCaptureSiteDomain(for: classify(appName: appName, bundleID: bundleID))
    }

    // MARK: - Cursor context via AXUIElement

    private static let maxContextChars = 100

    private static func cursorContext(pid: pid_t) -> (before: String?, after: String?) {
        guard AXIsProcessTrusted() else { return (nil, nil) }
        let sysWide = AXUIElementCreateSystemWide()
        AXUIElementSetMessagingTimeout(sysWide, 0.15)
        var focusedRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(sysWide, kAXFocusedUIElementAttribute as CFString, &focusedRef) == .success,
              let focused = focusedRef, CFGetTypeID(focused) == AXUIElementGetTypeID() else {
            return (nil, nil)
        }
        let element = focused as! AXUIElement

        // Skip secure text fields (password inputs)
        var roleRef: CFTypeRef?
        AXUIElementCopyAttributeValue(element, kAXRoleAttribute as CFString, &roleRef)
        if (roleRef as? String) == "AXSecureTextField" { return (nil, nil) }

        // Get full text value
        var valueRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, kAXValueAttribute as CFString, &valueRef) == .success,
              let fullText = valueRef as? String, !fullText.isEmpty else {
            return (nil, nil)
        }

        // Get selected text range to find cursor position
        var rangeRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, kAXSelectedTextRangeAttribute as CFString, &rangeRef) == .success,
              let rangeValue = rangeRef,
              CFGetTypeID(rangeValue) == AXValueGetTypeID() else {
            return (nil, nil)
        }
        var cfRange = CFRange(location: 0, length: 0)
        guard AXValueGetValue(rangeValue as! AXValue, .cfRange, &cfRange) else {
            return (nil, nil)
        }

        // cfRange.location is a UTF-16 offset; convert to String.Index via UTF-16 view
        let utf16 = fullText.utf16
        let cursorUTF16 = cfRange.location
        guard cursorUTF16 >= 0, cursorUTF16 <= utf16.count else { return (nil, nil) }

        let cursorIndex = String.Index(utf16Offset: cursorUTF16, in: fullText)

        let beforeStart = fullText.index(cursorIndex, offsetBy: -maxContextChars, limitedBy: fullText.startIndex) ?? fullText.startIndex
        let before = String(fullText[beforeStart..<cursorIndex])

        let afterEnd = fullText.index(cursorIndex, offsetBy: maxContextChars, limitedBy: fullText.endIndex) ?? fullText.endIndex
        let after = String(fullText[cursorIndex..<afterEnd])

        return (
            before.isEmpty ? nil : before,
            after.isEmpty ? nil : after
        )
    }

    // MARK: - Site key via AXUIElement (domain + first path for multi-service hosts)

    private static let multiServiceHosts: Set<String> = [
        "docs.google.com", "drive.google.com",
    ]

    private static func siteKey(pid: pid_t) -> String? {
        guard AXIsProcessTrusted() else { return nil }
        let appRef = AXUIElementCreateApplication(pid)
        AXUIElementSetMessagingTimeout(appRef, 0.5)
        var windowRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(appRef, kAXFocusedWindowAttribute as CFString, &windowRef) == .success else {
            axLogger.debug("siteKey: no focused window for pid \(pid)")
            return nil
        }
        guard let ref = windowRef, CFGetTypeID(ref) == AXUIElementGetTypeID() else {
            axLogger.debug("siteKey: windowRef nil or type mismatch")
            return nil
        }
        let window = ref as! AXUIElement

        // Pass 1: address bar (most reliable source of current page URL)
        if let url = findAddressBarURL(window, maxDepth: 6) {
            let key = siteKeyFrom(url)
            axLogger.info("siteKey(addressBar): url=\(url) → key=\(key ?? "nil")")
            return key
        }
        // Pass 2: AXURL attribute on any element (Safari AXWebArea, Comet AXGroup, etc.)
        if let url = findAXURL(window, maxDepth: 8) {
            let key = siteKeyFrom(url)
            axLogger.info("siteKey(AXURL): url=\(url) → key=\(key ?? "nil")")
            return key
        }
        axLogger.debug("siteKey: no URL found in AX tree for pid \(pid)")
        return nil
    }

    // MARK: - URL-based category classification

    private static let urlCategoryRules: [(Category, [String])] = [
        (.email, ["mail.google.com", "outlook.live.com", "outlook.office.com",
                  "mail.yahoo.com", "mail.proton.me", "fastmail.com"]),
        (.chat,  ["messenger.com", "web.whatsapp.com", "discord.com",
                  "teams.microsoft.com", "slack.com", "web.telegram.org",
                  "chat.openai.com", "claude.ai", "chatgpt.com"]),
        (.notes, ["notion.so", "docs.google.com", "onenote.com",
                  "evernote.com", "obsidian.md", "coda.io"]),
        (.code,  ["github.com", "gitlab.com", "bitbucket.org", "codepen.io",
                  "codesandbox.io", "replit.com", "stackblitz.com"]),
    ]

    static func classifyByURL(_ siteKey: String) -> Category? {
        let lower = siteKey.lowercased()
        for (category, patterns) in urlCategoryRules {
            if patterns.contains(where: { lower.hasPrefix($0) }) {
                return category
            }
        }
        return nil
    }

    // Pass 1: find address bar (AXTextField with AXURLField/AXSearchField subrole)
    private static func findAddressBarURL(_ element: AXUIElement, maxDepth: Int) -> String? {
        guard maxDepth > 0 else { return nil }

        var roleRef: CFTypeRef?
        AXUIElementCopyAttributeValue(element, kAXRoleAttribute as CFString, &roleRef)
        let role = roleRef as? String ?? ""

        if role == "AXTextField" {
            var subroleRef: CFTypeRef?
            AXUIElementCopyAttributeValue(element, kAXSubroleAttribute as CFString, &subroleRef)
            let subrole = subroleRef as? String ?? ""
            if subrole == "AXURLField" || subrole == "AXSearchField" {
                var valueRef: CFTypeRef?
                if AXUIElementCopyAttributeValue(element, kAXValueAttribute as CFString, &valueRef) == .success,
                   let value = valueRef as? String, !value.isEmpty {
                    // AXURLField content is always a URL; AXSearchField needs validation
                    if subrole == "AXURLField" || looksLikeURL(value) {
                        return value
                    }
                }
            }
        }

        var childrenRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, kAXChildrenAttribute as CFString, &childrenRef) == .success,
              let children = childrenRef as? [AXUIElement] else { return nil }
        for child in children.prefix(20) {
            if let url = findAddressBarURL(child, maxDepth: maxDepth - 1) { return url }
        }
        return nil
    }

    // Pass 2: find AXURL attribute on any element (Safari AXWebArea, Comet AXGroup, etc.)
    private static func findAXURL(_ element: AXUIElement, maxDepth: Int) -> String? {
        guard maxDepth > 0 else { return nil }

        var urlRef: CFTypeRef?
        if AXUIElementCopyAttributeValue(element, "AXURL" as CFString, &urlRef) == .success,
           let url = urlRef {
            if let cfURL = url as? URL { return cfURL.absoluteString }
            if CFGetTypeID(url) == CFURLGetTypeID() {
                return CFURLGetString(url as! CFURL) as String
            }
        }

        var childrenRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, kAXChildrenAttribute as CFString, &childrenRef) == .success,
              let children = childrenRef as? [AXUIElement] else { return nil }
        for child in children.prefix(20) {
            if let url = findAXURL(child, maxDepth: maxDepth - 1) { return url }
        }
        return nil
    }

    private static func looksLikeURL(_ text: String) -> Bool {
        guard text.contains("."), !text.contains(" ") else { return false }
        return text.hasPrefix("http://") || text.hasPrefix("https://")
            || text.range(of: #"^[a-zA-Z0-9]([a-zA-Z0-9-]*\.)+[a-zA-Z]{2,}"#, options: .regularExpression) != nil
    }

    private static func siteKeyFrom(_ urlString: String) -> String? {
        let trimmed = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        if let scheme = URLComponents(string: trimmed)?.scheme,
           scheme != "http", scheme != "https" {
            return nil
        }

        let normalized = trimmed.hasPrefix("http://") || trimmed.hasPrefix("https://")
            ? trimmed
            : "https://\(trimmed)"
        guard let comps = URLComponents(string: normalized), let host = comps.host else { return nil }
        let domain = host.hasPrefix("www.") ? String(host.dropFirst(4)) : host
        guard domain == "localhost" || domain.contains(".") else { return nil }
        // Include first path segment for multi-service hosts (docs.google.com/spreadsheets vs /document)
        if multiServiceHosts.contains(domain),
           let path = comps.path.split(separator: "/").first {
            return "\(domain)/\(path)"
        }
        return domain
    }

    static func siteKeyForTesting(from urlString: String) -> String? {
        siteKeyFrom(urlString)
    }

    // MARK: - App classification

    private static func shouldCaptureSiteDomain(for category: Category) -> Bool {
        category == .browser
    }

    private static func classify(appName: String, bundleID: String?) -> Category {
        let haystack = "\(bundleID ?? "") \(appName)".lowercased()
        let rules: [(Category, [String])] = [
            (.email, ["mail", "outlook", "superhuman", "spark", "airmail"]),
            (.chat, ["slack", "discord", "teams", "wechat", "weixin", "telegram",
                     "whatsapp", "messages", "line", "claude", "anthropic"]),
            (.code, ["xcode", "cursor", "visualstudiocode", "vscode", "jetbrains",
                     "intellij", "pycharm", "webstorm", "sublime", "zed", "nova", "codex"]),
            (.terminal, ["terminal", "iterm", "warp", "ghostty", "kitty", "alacritty"]),
            (.notes, ["notes", "notion", "obsidian", "bear", "evernote", "onenote", "craft"]),
            (.browser, ["safari", "chrome", "firefox", "edge", "arc", "brave", "orion", "comet"]),
        ]
        for (category, keywords) in rules {
            if keywords.contains(where: { haystack.contains($0) }) {
                return category
            }
        }
        return .generic
    }
}
