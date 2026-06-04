import SwiftUI
import Speech
import AVFoundation
@preconcurrency import ApplicationServices

struct GeneralSettingsView: View {
    @State private var prefs = PreferencesStore.shared
    @State private var micGranted = false
    @State private var speechGranted = false
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

            Section("refinement.default_prompt") {
                TextEditor(text: $prefs.defaultPrompt)
                    .font(DS.Font.body)
                    .frame(height: 50)
                    .scrollContentBackground(.hidden)
                    .background(DS.Colors.fieldBg)
                    .clipShape(RoundedRectangle(cornerRadius: 4))
                    .overlay(
                        RoundedRectangle(cornerRadius: 4)
                            .stroke(DS.Colors.secondary.opacity(0.3))
                    )

                FlowLayout(spacing: DS.Spacing.xs) {
                    ForEach(PromptSuggestion.all) { suggestion in
                        Button {
                            prefs.defaultPrompt = suggestion.prompt
                        } label: {
                            Text(suggestion.label)
                                .font(DS.Font.caption)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(DS.Colors.secondary.opacity(0.1))
                                .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }

                #if PROFEATURES
                Text("refinement.default_prompt_desc_pro")
                    .font(DS.Font.caption)
                    .foregroundStyle(DS.Colors.secondary)
                #else
                Text("refinement.default_prompt_desc")
                    .font(DS.Font.caption)
                    .foregroundStyle(DS.Colors.secondary)
                #endif
            }


            #if DIRECT
            Section("general.output_method") {
                HStack {
                    Image(systemName: accessibilityGranted ? "text.cursor" : "doc.on.clipboard")
                        .foregroundStyle(accessibilityGranted ? DS.Colors.success : DS.Colors.accent)
                        .font(.system(size: 14))
                    Text(accessibilityGranted
                        ? String(localized: "general.output_method.direct")
                        : String(localized: "general.output_method.clipboard"))
                        .font(DS.Font.bodyMedium)
                }

                Text(accessibilityGranted
                    ? String(localized: "general.output_method.direct_desc")
                    : String(localized: "general.output_method.clipboard_auto_desc"))
                    .font(DS.Font.caption)
                    .foregroundStyle(DS.Colors.secondary)
            }
            #endif

            Section("general.startup") {
                Toggle("general.launch_at_login", isOn: $prefs.launchAtLogin)
                    .onChange(of: prefs.launchAtLogin) { syncLaunchAtLogin() }
            }

            Section("general.permissions") {
                PermissionRow(
                    label: String(localized: "general.permission.microphone"),
                    granted: micGranted,
                    settingsURL: "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone"
                )
                PermissionRow(
                    label: String(localized: "general.permission.speech"),
                    granted: speechGranted,
                    settingsURL: "x-apple.systempreferences:com.apple.preference.security?Privacy_SpeechRecognition"
                )
                #if DIRECT
                PermissionRow(
                    label: String(localized: "general.permission.accessibility"),
                    granted: accessibilityGranted,
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
        micGranted = AVCaptureDevice.authorizationStatus(for: .audio) == .authorized
        speechGranted = SFSpeechRecognizer.authorizationStatus() == .authorized
        #if DIRECT
        accessibilityGranted = AXIsProcessTrusted()
        #endif
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
struct AppPromptEditor: View {
    @State private var prefs = PreferencesStore.shared
    @State private var store = HistoryStore.shared
    @State private var selectedApp = ""
    @State private var promptText = ""

    private var knownApps: [String] {
        Array(Set(store.entries.map(\.appName))).sorted()
    }

    private var configuredApps: [String] {
        prefs.appPrompts.keys.sorted()
    }

    var body: some View {
        if knownApps.isEmpty && configuredApps.isEmpty {
            Text("refinement.app_prompt.no_history")
                .font(DS.Font.caption)
                .foregroundStyle(DS.Colors.secondary)
        } else {
            VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                HStack {
                    Picker("refinement.app_prompt.select_app", selection: $selectedApp) {
                        Text("refinement.app_prompt.select_app").tag("")
                        ForEach(knownApps, id: \.self) { app in
                            Text(app).tag(app)
                        }
                    }
                    .frame(maxWidth: 200)
                }
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
                        HStack {
                            Text(app)
                                .font(DS.Font.body)
                            Spacer()
                            Text(prefs.appPrompts[app] ?? "")
                                .font(DS.Font.caption)
                                .foregroundStyle(DS.Colors.secondary)
                                .lineLimit(1)
                                .frame(maxWidth: 200, alignment: .trailing)
                            Button("refinement.app_prompt.delete") {
                                var prompts = prefs.appPrompts
                                prompts.removeValue(forKey: app)
                                prefs.appPrompts = prompts
                            }
                            .controlSize(.small)
                        }
                    }
                }
            }
        }
    }
}
#endif

struct PermissionRow: View {
    let label: String
    let granted: Bool
    let settingsURL: String
    var isAccessibility = false

    private nonisolated func promptAccessibility() {
        let key = kAXTrustedCheckOptionPrompt.takeUnretainedValue()
        let opts = [key: true] as CFDictionary
        AXIsProcessTrustedWithOptions(opts)
    }

    var body: some View {
        HStack {
            Image(systemName: granted ? "checkmark.circle.fill" : "xmark.circle")
                .foregroundStyle(granted ? .green : DS.Colors.error)
                .font(.system(size: 14))
            Text(label)
            Spacer()
            if granted {
                Text("general.permission.granted")
                    .font(DS.Font.caption)
                    .foregroundStyle(DS.Colors.secondary)
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

// MARK: - Prompt Suggestions

private struct PromptSuggestion: Identifiable {
    let id: String
    let label: String
    let prompt: String

    static let all: [PromptSuggestion] = [
        PromptSuggestion(
            id: "correct",
            label: String(localized: "refinement.suggestion.correct"),
            prompt: String(localized: "refinement.suggestion.correct_prompt")
        ),
        PromptSuggestion(
            id: "translate",
            label: String(localized: "refinement.suggestion.translate"),
            prompt: String(localized: "refinement.suggestion.translate_prompt")
        ),
        PromptSuggestion(
            id: "emoji",
            label: String(localized: "refinement.suggestion.emoji"),
            prompt: String(localized: "refinement.suggestion.emoji_prompt")
        ),
    ]
}

// MARK: - FlowLayout

private struct FlowLayout: Layout {
    var spacing: CGFloat = 4

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let rows = computeRows(proposal: proposal, subviews: subviews)
        var height: CGFloat = 0
        for (i, row) in rows.enumerated() {
            let rowHeight = row.map { subviews[$0].sizeThatFits(.unspecified).height }.max() ?? 0
            height += rowHeight + (i > 0 ? spacing : 0)
        }
        return CGSize(width: proposal.width ?? 0, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let rows = computeRows(proposal: proposal, subviews: subviews)
        var y = bounds.minY
        for row in rows {
            let rowHeight = row.map { subviews[$0].sizeThatFits(.unspecified).height }.max() ?? 0
            var x = bounds.minX
            for idx in row {
                let size = subviews[idx].sizeThatFits(.unspecified)
                subviews[idx].place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
                x += size.width + spacing
            }
            y += rowHeight + spacing
        }
    }

    private func computeRows(proposal: ProposedViewSize, subviews: Subviews) -> [[Int]] {
        let maxWidth = proposal.width ?? .infinity
        var rows: [[Int]] = [[]]
        var currentWidth: CGFloat = 0
        for (i, subview) in subviews.enumerated() {
            let size = subview.sizeThatFits(.unspecified)
            if !rows[rows.count - 1].isEmpty && currentWidth + spacing + size.width > maxWidth {
                rows.append([])
                currentWidth = 0
            }
            if currentWidth > 0 { currentWidth += spacing }
            currentWidth += size.width
            rows[rows.count - 1].append(i)
        }
        return rows
    }
}
