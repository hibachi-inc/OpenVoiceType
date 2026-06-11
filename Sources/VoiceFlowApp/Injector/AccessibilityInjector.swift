import AppKit
import Carbon.HIToolbox

/// Injects text by simulating ⌘V paste via CGEvent.
/// Requires Accessibility permission (AXIsProcessTrusted).
/// Used in the direct-distribution build (`#if DIRECT`).
@MainActor
struct AccessibilityInjector: TextInjecting {
    private enum Timing {
        static let clipboardSettleDelay: TimeInterval = 0.10  // 100ms — buffer after verified clipboard write
        static let pollInterval: TimeInterval = 0.05          // 50ms — AX polling interval
        static let maxRestoreWait: TimeInterval = 1.5         // 1.5s — fallback if AX can't detect consumption
    }

    func inject(_ text: String) {
        Self.performInjection(text)
    }

    private static func performInjection(_ text: String) {
        let pasteboard = NSPasteboard.general
        let savedItems = savePasteboard(pasteboard)

        let savedInputSource = TISCopyCurrentKeyboardInputSource().takeRetainedValue()
        switchToASCIIInputSourceIfNeeded()

        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)

        // Capture changeCount AFTER our write — this is the baseline for external-write detection
        let writeChangeCount = pasteboard.changeCount

        // Verify the write landed
        guard pasteboard.string(forType: .string) == text else {
            TISSelectInputSource(savedInputSource)
            return
        }

        // Wait for clipboard to settle, then paste
        DispatchQueue.main.asyncAfter(deadline: .now() + Timing.clipboardSettleDelay) {
            guard pasteboard.string(forType: .string) == text else {
                TISSelectInputSource(savedInputSource)
                return
            }
            postPaste()

            // Poll for paste consumption, then restore clipboard
            pollAndRestore(
                text: text,
                pasteboard: pasteboard,
                savedItems: savedItems,
                writeChangeCount: writeChangeCount,
                savedInputSource: savedInputSource,
                startTime: CFAbsoluteTimeGetCurrent()
            )
        }
    }

    // MARK: - Paste consumption detection

    private static func pollAndRestore(
        text: String,
        pasteboard: NSPasteboard,
        savedItems: [NSPasteboardItem],
        writeChangeCount: Int,
        savedInputSource: TISInputSource,
        startTime: CFAbsoluteTime
    ) {
        let elapsed = CFAbsoluteTimeGetCurrent() - startTime

        // Another process wrote to clipboard — skip restoration, still restore input source
        if pasteboard.changeCount != writeChangeCount {
            TISSelectInputSource(savedInputSource)
            return
        }

        // Check if target app consumed the paste via AX
        if focusedElementContains(text) || elapsed >= Timing.maxRestoreWait {
            restorePasteboard(pasteboard, items: savedItems)
            TISSelectInputSource(savedInputSource)
            return
        }

        // Keep polling
        DispatchQueue.main.asyncAfter(deadline: .now() + Timing.pollInterval) {
            pollAndRestore(
                text: text,
                pasteboard: pasteboard,
                savedItems: savedItems,
                writeChangeCount: writeChangeCount,
                savedInputSource: savedInputSource,
                startTime: startTime
            )
        }
    }

    /// Check if the focused text element contains the pasted text.
    private static func focusedElementContains(_ text: String) -> Bool {
        let systemWide = AXUIElementCreateSystemWide()
        var focusedRef: AnyObject?
        guard AXUIElementCopyAttributeValue(systemWide, kAXFocusedUIElementAttribute as CFString, &focusedRef) == .success,
              let focused = focusedRef,
              CFGetTypeID(focused) == AXUIElementGetTypeID() else { return false }
        let focusedElement = focused as! AXUIElement

        // Secure text fields never expose their value — skip AX check
        var roleRef: AnyObject?
        if AXUIElementCopyAttributeValue(focusedElement, kAXRoleAttribute as CFString, &roleRef) == .success,
           let role = roleRef as? String, role == "AXSecureTextField" {
            return false
        }

        var valueRef: AnyObject?
        guard AXUIElementCopyAttributeValue(focusedElement, kAXValueAttribute as CFString, &valueRef) == .success,
              let value = valueRef as? String else { return false }

        return value.contains(text)
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
