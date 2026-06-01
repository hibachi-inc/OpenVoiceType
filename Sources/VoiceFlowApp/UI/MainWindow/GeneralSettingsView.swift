import SwiftUI

struct GeneralSettingsView: View {
    @State private var prefs = PreferencesStore.shared

    private let locales: [(id: String, label: String)] = [
        ("system", "System Default"),
        ("en-US", "English (US)"),
        ("en-GB", "English (UK)"),
        ("ja-JP", "Japanese"),
        ("zh-Hans", "Chinese (Simplified)"),
        ("zh-Hant", "Chinese (Traditional)"),
        ("ko-KR", "Korean"),
        ("de-DE", "German"),
        ("fr-FR", "French"),
        ("es-ES", "Spanish"),
    ]

    var body: some View {
        Form {
            Section("Speech Recognition") {
                Picker("Language", selection: $prefs.locale) {
                    ForEach(locales, id: \.id) { locale in
                        Text(locale.label).tag(locale.id)
                    }
                }
                .pickerStyle(.menu)

                Text("On-device recognition. No audio is sent to any server.")
                    .font(DS.Font.caption)
                    .foregroundStyle(DS.Colors.secondary)
            }

            Section("Text Refinement") {
                Picker("Mode", selection: $prefs.refinementMode) {
                    ForEach(RefinementMode.allCases) { mode in
                        VStack(alignment: .leading) {
                            Text(mode.label)
                        }
                        .tag(mode)
                    }
                }
                .pickerStyle(.radioGroup)

                Text(prefs.refinementMode.description)
                    .font(DS.Font.caption)
                    .foregroundStyle(DS.Colors.secondary)
            }

            Section("Startup") {
                Toggle("Launch at login", isOn: $prefs.launchAtLogin)
                    .onChange(of: prefs.launchAtLogin) { syncLaunchAtLogin() }
            }
        }
        .formStyle(.grouped)
        .navigationTitle("General")
    }

    private func syncLaunchAtLogin() {
        guard let delegate = NSApp.delegate as? AppDelegate else { return }
        delegate.syncLaunchAtLogin()
    }
}
