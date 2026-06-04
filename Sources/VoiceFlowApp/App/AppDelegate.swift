import AppKit
import Carbon.HIToolbox
import ServiceManagement

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private let coordinator = RecordingCoordinator()
    private let mainWindow = MainWindowController()
    private let hotkey = GlobalHotkey()
    private let stopCmdV = GlobalHotkey()
    private let stopReturn = GlobalHotkey()
    private let cancelEsc = GlobalHotkey()
    #if PROFEATURES
    private var translateHotkeys: [GlobalHotkey] = []
    #endif
    #if DIRECT
    private let sparkleUpdater = SparkleUpdater()
    #endif
    private let prefs = PreferencesStore.shared
    private let appName: String = Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
        ?? Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String ?? "OpenVoiceText"

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupMainMenu()
        #if DIRECT
        sparkleUpdater.start()
        #endif
        coordinator.setup()
        coordinator.onStateChanged = { [weak self] in self?.handleStateChanged() }
        setupStatusItem()
        installHotkey()
        syncLaunchAtLogin()
        mainWindow.show()
    }

    // MARK: - Main Menu Bar

    private func setupMainMenu() {
        let mainMenu = NSMenu()

        // App menu
        let appMenu = NSMenu()
        appMenu.addItem(withTitle: String(localized: "menubar.about \(appName)"), action: #selector(showAbout), keyEquivalent: "")
        appMenu.addItem(.separator())
        #if DIRECT
        let checkUpdates = appMenu.addItem(
            withTitle: String(localized: "menubar.check_updates"),
            action: #selector(SparkleUpdater.checkForUpdates(_:)),
            keyEquivalent: ""
        )
        checkUpdates.target = sparkleUpdater
        #endif
        appMenu.addItem(withTitle: String(localized: "menubar.settings"), action: #selector(openSettings), keyEquivalent: ",")
        appMenu.addItem(.separator())
        let hideItem = appMenu.addItem(withTitle: String(localized: "menubar.hide \(appName)"), action: #selector(NSApplication.hide(_:)), keyEquivalent: "h")
        hideItem.target = NSApp
        let hideOthersItem = appMenu.addItem(withTitle: String(localized: "menubar.hide_others"), action: #selector(NSApplication.hideOtherApplications(_:)), keyEquivalent: "h")
        hideOthersItem.keyEquivalentModifierMask = [.command, .option]
        hideOthersItem.target = NSApp
        let showAllItem = appMenu.addItem(withTitle: String(localized: "menubar.show_all"), action: #selector(NSApplication.unhideAllApplications(_:)), keyEquivalent: "")
        showAllItem.target = NSApp
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: String(localized: "menubar.quit \(appName)"), action: #selector(terminateApp), keyEquivalent: "q")

        let appMenuItem = NSMenuItem()
        appMenuItem.submenu = appMenu
        mainMenu.addItem(appMenuItem)

        // File menu
        let fileMenu = NSMenu(title: String(localized: "menubar.file"))
        fileMenu.addItem(withTitle: String(localized: "menubar.close_window"), action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w")
        let fileMenuItem = NSMenuItem()
        fileMenuItem.submenu = fileMenu
        mainMenu.addItem(fileMenuItem)

        // Edit menu
        let editMenu = NSMenu(title: String(localized: "menubar.edit"))
        editMenu.addItem(withTitle: String(localized: "menubar.cut"), action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        editMenu.addItem(withTitle: String(localized: "menubar.copy"), action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        editMenu.addItem(withTitle: String(localized: "menubar.paste"), action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        editMenu.addItem(withTitle: String(localized: "menubar.select_all"), action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        let editMenuItem = NSMenuItem()
        editMenuItem.submenu = editMenu
        mainMenu.addItem(editMenuItem)

        // Window menu
        let windowMenu = NSMenu(title: String(localized: "menubar.window"))
        windowMenu.addItem(withTitle: String(localized: "menubar.minimize"), action: #selector(NSWindow.performMiniaturize(_:)), keyEquivalent: "m")
        let windowMenuItem = NSMenuItem()
        windowMenuItem.submenu = windowMenu
        mainMenu.addItem(windowMenuItem)
        NSApp.windowsMenu = windowMenu

        // Help menu
        let helpMenu = NSMenu(title: String(localized: "menubar.help"))
        helpMenu.addItem(withTitle: String(localized: "menubar.website"), action: #selector(openWebsite), keyEquivalent: "")
        let helpMenuItem = NSMenuItem()
        helpMenuItem.submenu = helpMenu
        mainMenu.addItem(helpMenuItem)
        NSApp.helpMenu = helpMenu

        NSApp.mainMenu = mainMenu
    }

    @objc private func showAbout() {
        mainWindow.show()
    }

    @objc private func openWebsite() {
        #if PROFEATURES
        NSWorkspace.shared.open(URL(string: "https://voicelatte.app/")!)
        #else
        NSWorkspace.shared.open(URL(string: "https://github.com/hibachi-inc/OpenVoiceText")!)
        #endif
    }

    // MARK: - Status Bar

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.image = NSImage(
            systemSymbolName: "mic.fill", accessibilityDescription: appName
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
        let title = coordinator.isRecording
            ? String(localized: "menu.stop_recording")
            : String(localized: "menu.start_recording \(shortcutLabel)")
        let item = NSMenuItem(title: title, action: #selector(toggleRecording), keyEquivalent: "")
        item.target = self
        menu.addItem(item)

        menu.addItem(.separator())
        let info = NSMenuItem(title: String(localized: "menu.shortcut_hint \(shortcutLabel)"), action: nil, keyEquivalent: "")
        info.isEnabled = false
        menu.addItem(info)

        menu.addItem(.separator())
        let settings = NSMenuItem(title: String(localized: "menu.settings"), action: #selector(openSettings), keyEquivalent: ",")
        settings.target = self
        menu.addItem(settings)

        menu.addItem(.separator())
        let quit = NSMenuItem(title: String(localized: "menu.quit \(appName)"), action: #selector(terminateApp), keyEquivalent: "q")
        quit.target = self
        menu.addItem(quit)
    }

    @objc private func openSettings() {
        mainWindow.show()
    }

    var recordingCoordinator: RecordingCoordinator { coordinator }

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

    // MARK: - Recording stop/cancel hotkeys

    private func installStopHotkeys() {
        // ⌘V → stop recording (text goes to clipboard, user can ⌘V again to paste)
        stopCmdV.register(keyCode: UInt32(kVK_ANSI_V), modifiers: UInt32(cmdKey)) { [weak self] in
            self?.coordinator.toggle()
        }
        // Return/Enter → stop recording
        stopReturn.register(keyCode: UInt32(kVK_Return), modifiers: 0) { [weak self] in
            self?.coordinator.toggle()
        }
        // Esc → cancel (no clipboard copy)
        cancelEsc.register(keyCode: UInt32(kVK_Escape), modifiers: 0) { [weak self] in
            self?.coordinator.cancel()
        }
    }

    private func uninstallStopHotkeys() {
        stopCmdV.unregister()
        stopReturn.unregister()
        cancelEsc.unregister()
    }

    @objc private func toggleRecording() {
        coordinator.toggle()
    }

    private func handleStateChanged() {
        if coordinator.isRecording {
            installStopHotkeys()
        } else {
            uninstallStopHotkeys()
        }
        updateStatusIcon()
    }

    private func updateStatusIcon() {
        let name = coordinator.isRecording ? "mic.fill.badge.plus" : "mic.fill"
        statusItem.button?.image = NSImage(
            systemSymbolName: name, accessibilityDescription: appName
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

    @objc private func terminateApp() {
        hotkey.unregister()
        uninstallStopHotkeys()
        #if PROFEATURES
        translateHotkeys.forEach { $0.unregister() }
        #endif
        coordinator.disconnect()
        NSApplication.shared.terminate(nil)
    }
}

extension AppDelegate {
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        mainWindow.show()
        return true
    }
}

extension AppDelegate: NSMenuDelegate {
    nonisolated func menuWillOpen(_ menu: NSMenu) {
        Task { @MainActor in self.rebuildMenu() }
    }
}
