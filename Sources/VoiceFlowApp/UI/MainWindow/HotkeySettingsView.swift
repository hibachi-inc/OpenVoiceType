import SwiftUI

struct HotkeySettingsView: View {
    @State private var prefs = PreferencesStore.shared

    var body: some View {
        Form {
            Section("hotkey.recording") {
                ShortcutRecorder(
                    label: String(localized: "hotkey.start_stop"),
                    modifier: $prefs.hotkeyModifier,
                    key: $prefs.hotkeyKey,
                    onChange: reinstallHotkey
                )

                Text("hotkey.hint")
                    .font(DS.Font.caption)
                    .foregroundStyle(DS.Colors.secondary)
            }
        }
        .formStyle(.grouped)
        .navigationTitle(String(localized: "sidebar.hotkey"))
    }

    private func reinstallHotkey() {
        guard let delegate = NSApp.delegate as? AppDelegate else { return }
        delegate.installHotkey()
    }
}
