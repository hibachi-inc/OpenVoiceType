import AppKit
import SwiftUI

@MainActor
final class MainWindowController {
    private var window: NSWindow?

    func show() {
        if let window, window.isVisible {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let contentView = MainWindowView()
        let hosting = NSHostingView(rootView: contentView)

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 640, height: 460),
            styleMask: [.titled, .closable, .miniaturizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.title = "OpenVoiceText"
        window.titlebarAppearsTransparent = true
        window.toolbarStyle = .unified
        window.backgroundColor = NSColor(name: nil) { ap in
            ap.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
                ? NSColor(srgbRed: 0.612, green: 0.447, blue: 0.298, alpha: 1)
                : NSColor(srgbRed: 0.949, green: 0.878, blue: 0.753, alpha: 1)
        }
        window.contentView = hosting
        window.center()
        window.isReleasedWhenClosed = false
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        self.window = window
    }
}
