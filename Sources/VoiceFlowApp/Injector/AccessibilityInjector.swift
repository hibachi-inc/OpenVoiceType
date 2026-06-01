import AppKit
import Carbon.HIToolbox

/// Injects text by simulating ⌘V paste via CGEvent.
/// Requires Accessibility permission (AXIsProcessTrusted).
/// Used in the direct-distribution build (`#if DIRECT`).
@MainActor
struct AccessibilityInjector: TextInjecting {
    private enum Timing {
        static let inputSourceDelay: TimeInterval  = 0.05    // 50ms — wait for input source switch
        static let preWriteDelay: TimeInterval     = 0.06    // 60ms — wait for pasteboard write to settle
        static let interPasteDelay: TimeInterval   = 0.14    // 140ms — gap between double-paste
        static let postPasteDelay: TimeInterval     = 0.22    // 220ms — wait for target app to process paste
    }

    func inject(_ text: String) {
        Self.performInjection(text)
    }

    private static func performInjection(_ text: String) {
        let pasteboard = NSPasteboard.general
        let savedItems = savePasteboard(pasteboard)
        let savedChangeCount = pasteboard.changeCount

        let savedInputSource = TISCopyCurrentKeyboardInputSource().takeRetainedValue()
        switchToASCIIInputSourceIfNeeded()

        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)

        let t1 = Timing.inputSourceDelay + Timing.preWriteDelay
        let t2 = t1 + Timing.interPasteDelay
        let t3 = t2 + Timing.postPasteDelay

        DispatchQueue.main.asyncAfter(deadline: .now() + t1) {
            postPaste()
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + t2) {
            postPaste()
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + t3) {
            if pasteboard.changeCount == savedChangeCount + 2 {
                restorePasteboard(pasteboard, items: savedItems)
            }
            TISSelectInputSource(savedInputSource)
        }
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
