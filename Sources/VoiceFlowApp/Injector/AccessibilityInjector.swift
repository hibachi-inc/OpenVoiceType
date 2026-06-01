import AppKit
import Carbon.HIToolbox

/// Injects text by simulating ⌘V paste via CGEvent.
/// Requires Accessibility permission (AXIsProcessTrusted).
/// Used in the direct-distribution build (`#if DIRECT`).
struct AccessibilityInjector: TextInjecting {
    private enum Timing {
        static let preWriteDelay: useconds_t       = 60_000   // 60ms — wait for pasteboard write to settle
        static let interPasteDelay: useconds_t     = 140_000  // 140ms — gap between double-paste
        static let postPasteDelay: useconds_t      = 220_000  // 220ms — wait for target app to process paste
        static let inputSourceDelay: useconds_t    = 50_000   // 50ms — wait for input source switch
    }

    func inject(_ text: String) {
        DispatchQueue.global(qos: .userInitiated).async {
            Self.performInjection(text)
        }
    }

    private static func performInjection(_ text: String) {
        let pasteboard = NSPasteboard.general
        let savedItems = savePasteboard(pasteboard)
        let savedChangeCount = pasteboard.changeCount

        let savedInputSource = TISCopyCurrentKeyboardInputSource().takeRetainedValue()
        switchToASCIIInputSourceIfNeeded()

        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)

        usleep(Timing.preWriteDelay)

        // Double-paste: some apps (notably Electron-based) drop the first paste event
        postPaste()
        usleep(Timing.interPasteDelay)
        postPaste()

        usleep(Timing.postPasteDelay)

        // clearContents() +1, setString() +1 = savedChangeCount + 2
        if pasteboard.changeCount == savedChangeCount + 2 {
            restorePasteboard(pasteboard, items: savedItems)
        }

        TISSelectInputSource(savedInputSource)
    }

    // MARK: - Paste simulation

    private static func postPaste() {
        let vKeyCode = CGKeyCode(kVK_ANSI_V)
        guard let keyDown = CGEvent(keyboardEventSource: nil, virtualKey: vKeyCode, keyDown: true),
              let keyUp = CGEvent(keyboardEventSource: nil, virtualKey: vKeyCode, keyDown: false) else { return }
        keyDown.flags = .maskCommand
        keyUp.flags = .maskCommand
        keyDown.post(tap: .cgAnnotatedSessionEventTap)
        keyUp.post(tap: .cgAnnotatedSessionEventTap)
    }

    // MARK: - Input source

    /// CJK input methods may intercept the paste; temporarily switch to ASCII layout.
    private static func switchToASCIIInputSourceIfNeeded() {
        guard let sources = TISCreateInputSourceList(
            [kTISPropertyInputSourceID: "com.apple.keylayout.ABC"] as CFDictionary,
            false
        )?.takeRetainedValue() as? [TISInputSource],
              let abc = sources.first else { return }
        TISSelectInputSource(abc)
        usleep(Timing.inputSourceDelay)
    }

    // MARK: - Pasteboard save/restore

    private static func savePasteboard(_ pasteboard: NSPasteboard) -> [NSPasteboardItem] {
        guard let items = pasteboard.pasteboardItems else { return [] }
        return items.map { item in
            let copy = NSPasteboardItem()
            for type in item.types {
                if let data = item.data(forType: type) {
                    copy.setData(data, forType: type)
                }
            }
            return copy
        }
    }

    private static func restorePasteboard(_ pasteboard: NSPasteboard, items: [NSPasteboardItem]) {
        pasteboard.clearContents()
        if !items.isEmpty {
            pasteboard.writeObjects(items)
        }
    }
}
