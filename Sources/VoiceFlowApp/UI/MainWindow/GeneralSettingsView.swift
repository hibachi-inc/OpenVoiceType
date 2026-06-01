import SwiftUI

struct GeneralSettingsView: View {
    @State private var prefs = PreferencesStore.shared

    private let locales: [(id: String, labelKey: LocalizedStringResource)] = [
        ("system", "general.locale.system"),
        ("en-US", "general.locale.en_us"),
        ("en-GB", "general.locale.en_gb"),
        ("ja-JP", "general.locale.ja"),
        ("zh-Hans", "general.locale.zh_hans"),
        ("zh-Hant", "general.locale.zh_hant"),
        ("ko-KR", "general.locale.ko"),
        ("de-DE", "general.locale.de"),
        ("fr-FR", "general.locale.fr"),
        ("es-ES", "general.locale.es"),
    ]

    private let appLanguages: [(id: String, labelKey: LocalizedStringResource)] = [
        ("system", "general.app_language.system"),
        ("en", "general.app_language.en"),
        ("ja", "general.app_language.ja"),
    ]

    var body: some View {
        Form {
            Section("general.app_language") {
                Picker("general.app_language", selection: $prefs.appLanguage) {
                    ForEach(appLanguages, id: \.id) { lang in
                        Text(String(localized: lang.labelKey)).tag(lang.id)
                    }
                }
                .pickerStyle(.menu)
                .onChange(of: prefs.appLanguage) {
                    restartApp()
                }
            }

            Section("general.speech_recognition") {
                Picker("general.language", selection: $prefs.locale) {
                    ForEach(locales, id: \.id) { locale in
                        Text(String(localized: locale.labelKey)).tag(locale.id)
                    }
                }
                .pickerStyle(.menu)

                Picker("general.stt_engine", selection: $prefs.sttEngine) {
                    Text("general.stt_engine.auto").tag(STTEngine.enhanced)
                    Text("general.stt_engine.classic").tag(STTEngine.classic)
                }
                .pickerStyle(.radioGroup)

                Text(prefs.sttEngine == .enhanced
                    ? String(localized: "general.stt_engine.auto_desc")
                    : String(localized: "general.stt_engine.classic_desc"))
                    .font(DS.Font.caption)
                    .foregroundStyle(DS.Colors.secondary)

                if prefs.sttEngine == .enhanced {
                    if #available(macOS 26, *) {
                        SpeechModelStatusView()
                    }
                }

                Text("general.on_device")
                    .font(DS.Font.caption)
                    .foregroundStyle(DS.Colors.secondary)
            }

            Section("general.refinement") {
                Picker("general.mode", selection: $prefs.refinementMode) {
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

            Section("general.startup") {
                Toggle("general.launch_at_login", isOn: $prefs.launchAtLogin)
                    .onChange(of: prefs.launchAtLogin) { syncLaunchAtLogin() }
            }

            Section {
                Button("general.restart_app") {
                    restartApp()
                }
            }
        }
        .formStyle(.grouped)
        .navigationTitle(String(localized: "sidebar.general"))
    }

    private func syncLaunchAtLogin() {
        guard let delegate = NSApp.delegate as? AppDelegate else { return }
        delegate.syncLaunchAtLogin()
    }

    private func restartApp() {
        let url = Bundle.main.bundleURL
        let config = NSWorkspace.OpenConfiguration()
        config.createsNewApplicationInstance = true
        NSWorkspace.shared.openApplication(at: url, configuration: config) { _, error in
            guard error == nil else { return }
            DispatchQueue.main.async {
                NSApplication.shared.terminate(nil)
            }
        }
    }
}

@available(macOS 26, *)
struct SpeechModelStatusView: View {
    @State private var manager = SpeechModelManager.shared

    var body: some View {
        HStack(spacing: DS.Spacing.sm) {
            switch manager.status {
            case .checking:
                ProgressView()
                    .controlSize(.small)
                Text("general.model.checking")
                    .font(DS.Font.caption)
                    .foregroundStyle(DS.Colors.secondary)

            case .installed:
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                    .font(.system(size: 14))
                Text("general.model.installed")
                    .font(DS.Font.caption)
                    .foregroundStyle(DS.Colors.secondary)

            case .notInstalled:
                Image(systemName: "arrow.down.circle")
                    .foregroundStyle(DS.Colors.accent)
                    .font(.system(size: 14))
                Text("general.model.not_installed")
                    .font(DS.Font.caption)
                    .foregroundStyle(DS.Colors.secondary)
                Spacer()
                Button("general.model.download") {
                    manager.download()
                }
                .controlSize(.small)

            case .downloading(let progress):
                ProgressView(value: progress)
                    .frame(width: 80)
                Text("general.model.downloading \(Int(progress * 100))")
                    .font(DS.Font.caption)
                    .foregroundStyle(DS.Colors.secondary)
                Spacer()
                Button("general.model.cancel") {
                    manager.cancelDownload()
                }
                .controlSize(.small)

            case .unsupported:
                Image(systemName: "xmark.circle")
                    .foregroundStyle(DS.Colors.secondary)
                    .font(.system(size: 14))
                Text("general.model.unsupported")
                    .font(DS.Font.caption)
                    .foregroundStyle(DS.Colors.secondary)

            case .error(let msg):
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(DS.Colors.error)
                    .font(.system(size: 14))
                Text(msg)
                    .font(DS.Font.caption)
                    .foregroundStyle(DS.Colors.error)
                    .lineLimit(1)
                Spacer()
                Button("general.model.retry") {
                    manager.download()
                }
                .controlSize(.small)
            }
        }
        .onAppear { manager.checkStatus() }
        .onChange(of: PreferencesStore.shared.locale) { manager.checkStatus() }
    }
}
