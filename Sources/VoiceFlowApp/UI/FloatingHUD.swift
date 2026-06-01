import AppKit
import SwiftUI

@MainActor
final class FloatingHUD: HUDProtocol {
    private var panel: NSPanel?
    private var hostingView: NSHostingView<FloatingHUDView>?
    private var status: HUDStatus = .listening
    private var transcript = ""
    private var audioLevel: Float = 0
    private var engineLabel = ""
    private var autoHideTask: Task<Void, Never>?
    private var lastAudioLevelUpdate: ContinuousClock.Instant = .now
    var onTap: (() -> Void)?

    private var shortcutLabel: String {
        let prefs = PreferencesStore.shared
        return "\(prefs.hotkeyModifier.symbol)\(prefs.hotkeyKey.label)"
    }

    func showListening() {
        cancelAutoHide()
        status = .listening
        transcript = ""
        audioLevel = 0
        show()
    }

    func showProcessing(transcript: String) {
        cancelAutoHide()
        status = .processing
        self.transcript = transcript
        updateContent()
    }

    func showCopied(text: String) {
        cancelAutoHide()
        status = .copied
        transcript = text
        updateContent()
        scheduleAutoHide(after: .seconds(2))
    }

    func showInserted(text: String) {
        cancelAutoHide()
        status = .inserted
        transcript = text
        updateContent()
        scheduleAutoHide(after: .seconds(1.5))
    }

    func showError(_ message: String) {
        cancelAutoHide()
        status = .error(message)
        updateContent()
        scheduleAutoHide(after: .seconds(3))
    }

    func updateTranscript(_ text: String) {
        transcript = text
        updateContent()
    }

    func updateEngine(_ engine: String) {
        engineLabel = engine == "enhanced"
            ? String(localized: "engine.enhanced_short")
            : String(localized: "engine.classic_short")
        updateContent()
    }

    func updateAudioLevel(_ level: Float) {
        let now = ContinuousClock.now
        guard now - lastAudioLevelUpdate >= .milliseconds(80) else { return }
        lastAudioLevelUpdate = now
        audioLevel = level
        updateContent()
    }

    func hide() {
        cancelAutoHide()
        guard let panel else { return }
        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = 0.22
            panel.animator().alphaValue = 0
        }, completionHandler: { [weak self] in
            Task { @MainActor in
                self?.panel?.orderOut(nil)
                self?.panel?.alphaValue = 1
            }
        })
    }

    // MARK: - Private

    private func cancelAutoHide() {
        autoHideTask?.cancel()
        autoHideTask = nil
    }

    private func scheduleAutoHide(after duration: Duration) {
        autoHideTask = Task { @MainActor in
            try? await Task.sleep(for: duration)
            guard !Task.isCancelled else { return }
            hide()
        }
    }

    private func show() {
        let panel = ensurePanel()
        updateContent()
        positionPanel(panel)
        panel.alphaValue = 0
        panel.orderFrontRegardless()
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.3
            ctx.timingFunction = CAMediaTimingFunction(controlPoints: 0.2, 0.9, 0.2, 1.0)
            panel.animator().alphaValue = 1
        }
    }

    private func ensurePanel() -> NSPanel {
        if let panel { return panel }
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 300, height: 60),
            styleMask: [.borderless, .nonactivatingPanel, .fullSizeContentView],
            backing: .buffered, defer: false
        )
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.level = .statusBar
        panel.hasShadow = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
        panel.hidesOnDeactivate = false
        panel.isMovableByWindowBackground = false
        panel.acceptsMouseMovedEvents = true
        panel.ignoresMouseEvents = false

        let hosting = NSHostingView(rootView: makeView())
        hosting.frame = panel.contentView!.bounds
        hosting.autoresizingMask = [.width, .height]
        panel.contentView?.addSubview(hosting)
        self.panel = panel
        self.hostingView = hosting
        return panel
    }

    private func updateContent() {
        hostingView?.rootView = makeView()
        guard let panel else { return }
        let w = calculateWidth()
        let frame = panel.frame
        panel.setFrame(
            NSRect(x: frame.midX - w / 2, y: frame.origin.y, width: w, height: DS.Panel.hudHeight),
            display: true
        )
    }

    private func makeView() -> FloatingHUDView {
        FloatingHUDView(
            status: status,
            transcript: transcript,
            audioLevel: audioLevel,
            shortcutLabel: shortcutLabel,
            engineLabel: engineLabel,
            onTap: { [weak self] in self?.onTap?() }
        )
    }

    private func positionPanel(_ panel: NSPanel) {
        guard let screen = NSScreen.main else { return }
        let w = calculateWidth()
        let visibleFrame = screen.visibleFrame
        panel.setFrame(
            NSRect(x: visibleFrame.midX - w / 2, y: visibleFrame.minY + DS.Panel.hudBottomOffset, width: w, height: DS.Panel.hudHeight),
            display: true
        )
    }

    private func calculateWidth() -> CGFloat {
        let maxWidth: CGFloat = 500
        if transcript.isEmpty {
            return 180
        }
        let charCount = transcript.suffix(80).count
        let textWidth = CGFloat(min(charCount, 30)) * 8
        return min(maxWidth, 180 + textWidth)
    }
}
