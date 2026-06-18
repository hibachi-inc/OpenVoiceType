import SwiftUI
import Speech
import AVFoundation
@preconcurrency import ApplicationServices

struct GeneralSettingsView: View {
    @State private var prefs = PreferencesStore.shared
    @State private var micStatus: AVAuthorizationStatus = .notDetermined
    @State private var speechStatus: SFSpeechRecognizerAuthorizationStatus = .notDetermined
    @State private var accessibilityGranted = false

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

                if prefs.sttEngine == .classic {
                    Text("general.stt_engine.classic_desc")
                        .font(DS.Font.caption)
                        .foregroundStyle(DS.Colors.secondary)
                }

                if prefs.sttEngine == .enhanced {
                    if #available(macOS 26, *) {
                        SpeechModelStatusView()
                    }
                }

                Text("general.on_device")
                    .font(DS.Font.caption)
                    .foregroundStyle(DS.Colors.secondary)

                Toggle("general.mute_other_audio", isOn: $prefs.muteOtherAudio)
                Text("general.mute_other_audio_desc")
                    .font(DS.Font.caption)
                    .foregroundStyle(DS.Colors.secondary)
            }


            #if DIRECT
            Section("general.output_method") {
                if accessibilityGranted {
                    Picker("general.output_method", selection: $prefs.useDirectPaste) {
                        Text("general.output_method.direct").tag(true)
                        Text("general.output_method.clipboard").tag(false)
                    }
                    .pickerStyle(.radioGroup)

                    Text(prefs.useDirectPaste
                        ? String(localized: "general.output_method.direct_desc")
                        : String(localized: "general.output_method.clipboard_desc"))
                        .font(DS.Font.caption)
                        .foregroundStyle(DS.Colors.secondary)
                } else {
                    HStack {
                        Image(systemName: "doc.on.clipboard")
                            .foregroundStyle(DS.Colors.accent)
                            .font(.system(size: 14))
                        Text("general.output_method.clipboard")
                            .font(DS.Font.bodyMedium)
                    }

                    Text("general.output_method.clipboard_auto_desc")
                        .font(DS.Font.caption)
                        .foregroundStyle(DS.Colors.secondary)
                }
            }
            #endif

            #if !PROFEATURES
            Section("general.refinement") {
                Picker("general.mode", selection: $prefs.refinementMode) {
                    ForEach(RefinementMode.allCases) { mode in
                        Text(mode.label).tag(mode)
                    }
                }
                .pickerStyle(.radioGroup)

                Text(prefs.refinementMode.description)
                    .font(DS.Font.caption)
                    .foregroundStyle(DS.Colors.secondary)

                if prefs.refinementMode == .refine {
                    TextEditor(text: $prefs.defaultPrompt)
                        .font(DS.Font.body)
                        .frame(height: 110)
                        .scrollContentBackground(.hidden)
                        .background(DS.Colors.fieldBg)
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                        .overlay(
                            RoundedRectangle(cornerRadius: 4)
                                .stroke(DS.Colors.secondary.opacity(0.3))
                        )

                    HStack {
                        Spacer()
                        Button("refinement.default_prompt.reset", systemImage: "arrow.counterclockwise") {
                            prefs.resetDefaultPrompt()
                        }
                        .disabled(!prefs.isDefaultPromptCustomized)
                        .controlSize(.small)
                    }

                    Text("refinement.default_prompt_desc")
                        .font(DS.Font.caption)
                        .foregroundStyle(DS.Colors.secondary)
                }
            }
            #endif

            Section("general.startup") {
                Toggle("general.launch_at_login", isOn: $prefs.launchAtLogin)
                    .onChange(of: prefs.launchAtLogin) { syncLaunchAtLogin() }
            }

            Section("general.permissions") {
                PermissionRow(
                    label: String(localized: "general.permission.microphone"),
                    state: permissionState(for: micStatus),
                    settingsURL: "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone",
                    onRequest: requestMicrophonePermission
                )
                PermissionRow(
                    label: String(localized: "general.permission.speech"),
                    state: permissionState(for: speechStatus),
                    settingsURL: "x-apple.systempreferences:com.apple.preference.security?Privacy_SpeechRecognition",
                    onRequest: requestSpeechPermission
                )
                #if DIRECT
                PermissionRow(
                    label: String(localized: "general.permission.accessibility"),
                    state: accessibilityGranted ? .granted : .needsSettings,
                    settingsURL: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility",
                    isAccessibility: true
                )
                Text("general.permission.accessibility_desc")
                    .font(DS.Font.caption)
                    .foregroundStyle(DS.Colors.secondary)
                #endif
            }

        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
        .background(DS.Colors.windowBg)
        .navigationTitle(String(localized: "sidebar.general"))
        .onAppear { refreshPermissions() }
        .onReceive(Timer.publish(every: 2, on: .main, in: .common).autoconnect()) { _ in
            refreshPermissions()
        }
    }

    private func refreshPermissions() {
        micStatus = AVCaptureDevice.authorizationStatus(for: .audio)
        speechStatus = SFSpeechRecognizer.authorizationStatus()
        #if DIRECT
        accessibilityGranted = AXIsProcessTrusted()
        #endif
    }

    private func permissionState(for status: AVAuthorizationStatus) -> PermissionActionState {
        switch status {
        case .authorized:
            .granted
        case .notDetermined:
            .requestable
        case .denied, .restricted:
            .needsSettings
        @unknown default:
            .needsSettings
        }
    }

    private func permissionState(for status: SFSpeechRecognizerAuthorizationStatus) -> PermissionActionState {
        switch status {
        case .authorized:
            .granted
        case .notDetermined:
            .requestable
        case .denied, .restricted:
            .needsSettings
        @unknown default:
            .needsSettings
        }
    }

    private func requestMicrophonePermission() {
        Task {
            _ = await AVCaptureDevice.requestAccess(for: .audio)
            await MainActor.run { refreshPermissions() }
        }
    }

    private func requestSpeechPermission() {
        Task {
            _ = await withCheckedContinuation { cont in
                SFSpeechRecognizer.requestAuthorization { cont.resume(returning: $0) }
            }
            await MainActor.run { refreshPermissions() }
        }
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

#if PROFEATURES
struct CategoryPromptEditor: View {
    @State private var prefs = PreferencesStore.shared
    @State private var selectedCategory: AppContext.Category = .code
    @State private var promptText = ""

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            Picker("refinement.type_prompt.select_type", selection: $selectedCategory) {
                ForEach(AppContext.Category.allCases, id: \.rawValue) { category in
                    Text(categoryDisplayName(category)).tag(category)
                }
            }
            .pickerStyle(.menu)
            .frame(maxWidth: 220)
            .onChange(of: selectedCategory) {
                promptText = prefs.appPrompts[categoryPromptKey(selectedCategory)] ?? ""
            }
            .onAppear {
                promptText = prefs.appPrompts[categoryPromptKey(selectedCategory)] ?? ""
            }

            TextEditor(text: $promptText)
                .font(DS.Font.body)
                .frame(height: 60)
                .scrollContentBackground(.hidden)
                .background(DS.Colors.fieldBg)
                .clipShape(RoundedRectangle(cornerRadius: 4))
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(DS.Colors.secondary.opacity(0.3))
                )
                .onChange(of: promptText) {
                    savePrompt(promptText, for: selectedCategory)
                }

            ForEach(configuredCategories, id: \.rawValue) { category in
                if category != selectedCategory {
                    PromptSummaryRow(
                        title: categoryDisplayName(category),
                        prompt: prefs.appPrompts[categoryPromptKey(category)] ?? ""
                    ) {
                        var prompts = prefs.appPrompts
                        prompts.removeValue(forKey: categoryPromptKey(category))
                        prefs.appPrompts = prompts
                    }
                }
            }
        }
    }

    private var configuredCategories: [AppContext.Category] {
        AppContext.Category.allCases.filter { category in
            !(prefs.appPrompts[categoryPromptKey(category)] ?? "").isEmpty
        }
    }

    private func savePrompt(_ text: String, for category: AppContext.Category) {
        var prompts = prefs.appPrompts
        let key = categoryPromptKey(category)
        if text.isEmpty {
            prompts.removeValue(forKey: key)
        } else {
            prompts[key] = text
        }
        prefs.appPrompts = prompts
    }
}

struct AppSpecificPromptEditor: View {
    @State private var prefs = PreferencesStore.shared
    @State private var store = HistoryStore.shared
    @State private var selectedApp = ""
    @State private var promptText = ""

    private var knownApps: [String] {
        Array(Set(store.entries.map(\.promptKey))).sorted()
    }

    private var configuredApps: [String] {
        prefs.appPrompts.keys
            .filter { category(fromPromptKey: $0) == nil }
            .sorted()
    }

    var body: some View {
        if knownApps.isEmpty && configuredApps.isEmpty {
            Text("refinement.app_prompt.no_history")
                .font(DS.Font.caption)
                .foregroundStyle(DS.Colors.secondary)
        } else {
            VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                Picker("refinement.app_prompt.select_app", selection: $selectedApp) {
                    Text("refinement.app_prompt.select_app").tag("")
                    ForEach(knownApps, id: \.self) { app in
                        Text(app).tag(app)
                    }
                }
                .frame(maxWidth: 220)
                .onChange(of: selectedApp) {
                    promptText = prefs.appPrompts[selectedApp] ?? ""
                }

                if !selectedApp.isEmpty {
                    TextEditor(text: $promptText)
                        .font(DS.Font.body)
                        .frame(height: 60)
                        .scrollContentBackground(.hidden)
                        .background(DS.Colors.fieldBg)
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                        .overlay(
                            RoundedRectangle(cornerRadius: 4)
                                .stroke(DS.Colors.secondary.opacity(0.3))
                        )
                        .onChange(of: promptText) {
                            var prompts = prefs.appPrompts
                            if promptText.isEmpty {
                                prompts.removeValue(forKey: selectedApp)
                            } else {
                                prompts[selectedApp] = promptText
                            }
                            prefs.appPrompts = prompts
                        }
                }

                ForEach(configuredApps, id: \.self) { app in
                    if app != selectedApp {
                        PromptSummaryRow(title: app, prompt: prefs.appPrompts[app] ?? "") {
                            var prompts = prefs.appPrompts
                            prompts.removeValue(forKey: app)
                            prefs.appPrompts = prompts
                        }
                    }
                }
            }
        }
    }
}

private struct PromptSummaryRow: View {
    let title: String
    let prompt: String
    let onDelete: () -> Void

    var body: some View {
        HStack {
            Text(title)
                .font(DS.Font.body)
            Spacer()
            Text(prompt)
                .font(DS.Font.caption)
                .foregroundStyle(DS.Colors.secondary)
                .lineLimit(1)
                .frame(maxWidth: 200, alignment: .trailing)
            Button("refinement.app_prompt.delete", action: onDelete)
                .controlSize(.small)
        }
    }
}

private func categoryPromptKey(_ category: AppContext.Category) -> String {
    "__category__:\(category.rawValue)"
}

private func category(fromPromptKey key: String) -> AppContext.Category? {
    let prefix = "__category__:"
    guard key.hasPrefix(prefix) else { return nil }
    return AppContext.Category(rawValue: String(key.dropFirst(prefix.count)))
}

private func categoryDisplayName(_ category: AppContext.Category) -> String {
    switch category {
    case .chat: String(localized: "refinement.app_prompt.category.chat")
    case .email: String(localized: "refinement.app_prompt.category.email")
    case .code: String(localized: "refinement.app_prompt.category.code")
    case .terminal: String(localized: "refinement.app_prompt.category.terminal")
    case .notes: String(localized: "refinement.app_prompt.category.notes")
    case .browser: String(localized: "refinement.app_prompt.category.browser")
    case .generic: String(localized: "refinement.app_prompt.category.generic")
    }
}

#endif

struct PermissionRow: View {
    let label: String
    let state: PermissionActionState
    let settingsURL: String
    var isAccessibility = false
    var onRequest: (() -> Void)?

    private nonisolated func promptAccessibility() {
        let key = kAXTrustedCheckOptionPrompt.takeUnretainedValue()
        let opts = [key: true] as CFDictionary
        AXIsProcessTrustedWithOptions(opts)
    }

    var body: some View {
        HStack {
            Image(systemName: state == .granted ? "checkmark.circle.fill" : "xmark.circle")
                .foregroundStyle(state == .granted ? .green : DS.Colors.error)
                .font(.system(size: 14))
            Text(label)
            Spacer()
            if state == .granted {
                Text("general.permission.granted")
                    .font(DS.Font.caption)
                    .foregroundStyle(DS.Colors.secondary)
            } else {
                if state == .requestable, let onRequest {
                    Button("general.permission.request_access", action: onRequest)
                        .controlSize(.small)
                } else {
                    Button("general.permission.open_settings") {
                        if isAccessibility {
                            promptAccessibility()
                        } else if let url = URL(string: settingsURL) {
                            NSWorkspace.shared.open(url)
                        }
                    }
                    .controlSize(.small)
                }
            }
        }
    }
}

enum PermissionActionState {
    case granted
    case requestable
    case needsSettings
}
