import AppKit
import Speech
import AVFoundation
import ServiceManagement

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private let coordinator = RecordingCoordinator()
    private let mainWindow = MainWindowController()
    private let hotkey = GlobalHotkey()
    #if PROFEATURES
    private var translateHotkeys: [GlobalHotkey] = []
    #endif
    private let prefs = PreferencesStore.shared

    func applicationDidFinishLaunching(_ notification: Notification) {
        coordinator.setup()
        coordinator.onStateChanged = { [weak self] in self?.updateStatusIcon() }
        setupStatusItem()
        installHotkey()
        syncLaunchAtLogin()
        Task { await requestPermissions() }
    }

    // MARK: - Status Bar

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.image = NSImage(
            systemSymbolName: "mic.fill", accessibilityDescription: "OpenVoiceText"
        )
        let menu = NSMenu()
        menu.delegate = self
        statusItem.menu = menu
        rebuildMenu()
    }

    private func rebuildMenu() {
        guard let menu = statusItem.menu else { return }
        menu.removeAllItems()

        let shortcutLabel = "\(prefs.hotkeyModifier.symbol)\(prefs.hotkeyKey.label)"
        let title = coordinator.isRecording ? "Stop Recording" : "Start Recording (\(shortcutLabel))"
        let item = NSMenuItem(title: title, action: #selector(toggleRecording), keyEquivalent: "")
        item.target = self
        menu.addItem(item)

        menu.addItem(.separator())
        let info = NSMenuItem(title: "\(shortcutLabel) to toggle recording", action: nil, keyEquivalent: "")
        info.isEnabled = false
        menu.addItem(info)

        menu.addItem(.separator())
        let settings = NSMenuItem(title: "Settings...", action: #selector(openSettings), keyEquivalent: ",")
        settings.target = self
        menu.addItem(settings)

        menu.addItem(.separator())
        let quit = NSMenuItem(title: "Quit OpenVoiceText", action: #selector(terminateApp), keyEquivalent: "q")
        quit.target = self
        menu.addItem(quit)
    }

    @objc private func openSettings() {
        mainWindow.show()
    }

    // MARK: - Hotkey

    func installHotkey() {
        hotkey.register(
            keyCode: UInt32(prefs.hotkeyKey.keyCode),
            modifiers: prefs.hotkeyModifier.carbonModifier
        ) { [weak self] in
            self?.toggleRecording()
        }

        #if PROFEATURES
        translateHotkeys.forEach { $0.unregister() }
        let mainKey = (prefs.hotkeyKey.keyCode, prefs.hotkeyModifier.carbonModifier)
        var registeredKeys = Set<String>()
        registeredKeys.insert("\(mainKey.0)-\(mainKey.1)")

        translateHotkeys = prefs.translationLanguages.compactMap { lang in
            let langKey = (lang.key.keyCode, lang.modifier.carbonModifier)
            let keyStr = "\(langKey.0)-\(langKey.1)"
            // Skip duplicates: same shortcut as main hotkey or another translation language
            guard registeredKeys.insert(keyStr).inserted else { return nil }
            let hk = GlobalHotkey()
            let code = lang.code
            hk.register(
                keyCode: UInt32(lang.key.keyCode),
                modifiers: lang.modifier.carbonModifier
            ) { [weak self] in
                self?.coordinator.toggleTranslation(code)
            }
            return hk
        }
        #endif
    }

    @objc private func toggleRecording() {
        coordinator.toggle()
    }

    private func updateStatusIcon() {
        let name = coordinator.isRecording ? "mic.fill.badge.plus" : "mic.fill"
        statusItem.button?.image = NSImage(
            systemSymbolName: name, accessibilityDescription: "OpenVoiceText"
        )
        rebuildMenu()
    }

    // MARK: - Launch at Login

    func syncLaunchAtLogin() {
        do {
            if prefs.launchAtLogin {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {}
    }

    // MARK: - Permissions

    private nonisolated func requestPermissions() async {
        let speech = await withCheckedContinuation { cont in
            SFSpeechRecognizer.requestAuthorization { cont.resume(returning: $0) }
        }
        if speech != .authorized {
            await MainActor.run { coordinator.showPermissionError("Speech recognition permission required.") }
        }
        let mic = await AVCaptureDevice.requestAccess(for: .audio)
        if !mic {
            await MainActor.run { coordinator.showPermissionError("Microphone permission required.") }
        }
    }

    @objc private func terminateApp() {
        hotkey.unregister()
        #if PROFEATURES
        translateHotkeys.forEach { $0.unregister() }
        #endif
        coordinator.disconnect()
        NSApplication.shared.terminate(nil)
    }
}

extension AppDelegate: NSMenuDelegate {
    nonisolated func menuWillOpen(_ menu: NSMenu) {
        Task { @MainActor in self.rebuildMenu() }
    }
}
