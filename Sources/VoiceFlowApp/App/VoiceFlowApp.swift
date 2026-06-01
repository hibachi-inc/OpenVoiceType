import AppKit

@main
struct VoiceFlowApp {
    static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.setActivationPolicy(.regular)
        app.delegate = delegate
        // app.run() never returns, so delegate stays on the stack
        // and the weak NSApplication.delegate reference remains valid.
        app.run()
    }
}
