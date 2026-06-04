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

            Section("hotkey.push_to_talk") {
                Toggle("hotkey.push_to_talk_toggle", isOn: $prefs.pushToTalk)
                    .onChange(of: prefs.pushToTalk) { reinstallPushToTalk() }

                Text("hotkey.push_to_talk_desc \(prefs.hotkeyModifier.symbol)")
                    .font(DS.Font.caption)
                    .foregroundStyle(DS.Colors.secondary)
            }

            Section {
                Button("hotkey.reset", role: .destructive) {
                    prefs.hotkeyModifier = .control
                    prefs.hotkeyKey = .v
                    reinstallHotkey()
                }
            }
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
        .background(DS.Colors.windowBg)
        .navigationTitle(String(localized: "sidebar.hotkey"))
    }

    private func reinstallHotkey() {
        guard let delegate = NSApp.delegate as? AppDelegate else { return }
        delegate.installHotkey()
        delegate.installPushToTalk()
    }

    private func reinstallPushToTalk() {
        guard let delegate = NSApp.delegate as? AppDelegate else { return }
        delegate.installPushToTalk()
    }
}
