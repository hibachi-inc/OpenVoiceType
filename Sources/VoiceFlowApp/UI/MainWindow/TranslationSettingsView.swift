#if PROFEATURES
import SwiftUI

struct TranslationSettingsView: View {
    @State private var prefs = PreferencesStore.shared
    @State private var showingAddSheet = false

    var body: some View {
        Form {
            Section("Enabled Languages") {
                if prefs.translationLanguages.isEmpty {
                    Text("No translation languages enabled.")
                        .foregroundStyle(DS.Colors.secondary)
                } else {
                    ForEach(prefs.translationLanguages) { lang in
                        let langID = lang.id
                        HStack {
                            Text(lang.label)
                                .font(DS.Font.bodyMedium)
                            Text(lang.code)
                                .font(DS.Font.caption)
                                .foregroundStyle(DS.Colors.secondary)
                            Spacer()
                            ShortcutRecorder(
                                label: "",
                                modifier: Binding(
                                    get: { prefs.translationLanguages.first { $0.id == langID }?.modifier ?? .control },
                                    set: { val in
                                        if let i = prefs.translationLanguages.firstIndex(where: { $0.id == langID }) {
                                            prefs.translationLanguages[i].modifier = val
                                        }
                                    }
                                ),
                                key: Binding(
                                    get: { prefs.translationLanguages.first { $0.id == langID }?.key ?? .space },
                                    set: { val in
                                        if let i = prefs.translationLanguages.firstIndex(where: { $0.id == langID }) {
                                            prefs.translationLanguages[i].key = val
                                        }
                                    }
                                ),
                                onChange: reinstallHotkey
                            )
                            Button(role: .destructive) {
                                prefs.translationLanguages.removeAll { $0.id == langID }
                                reinstallHotkey()
                            } label: {
                                Image(systemName: "minus.circle.fill")
                                    .foregroundStyle(.red)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                Button("Add Language...") { showingAddSheet = true }
            }

            Section("How it works") {
                Text("Each language has its own shortcut. Press the shortcut to record, speak in any language, and get translated text.")
                    .font(DS.Font.caption)
                    .foregroundStyle(DS.Colors.secondary)
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Translation")
        .sheet(isPresented: $showingAddSheet) {
            AddLanguageSheet(onAdd: { lang in
                prefs.translationLanguages.append(lang)
                reinstallHotkey()
            })
        }
    }

    private func reinstallHotkey() {
        guard let delegate = NSApp.delegate as? AppDelegate else { return }
        delegate.installHotkey()
    }
}

struct AddLanguageSheet: View {
    let onAdd: (TranslationLanguage) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var selected: AvailableLanguage = .english

    private var enabledCodes: Set<String> {
        Set(PreferencesStore.shared.translationLanguages.map(\.code))
    }
    private var availableLanguages: [AvailableLanguage] {
        AvailableLanguage.allCases.filter { !enabledCodes.contains($0.rawValue) }
    }

    var body: some View {
        VStack(spacing: DS.Spacing.lg) {
            Text("Add Translation Language").font(DS.Font.headline)
            if availableLanguages.isEmpty {
                Text("All languages are already enabled.")
                    .foregroundStyle(DS.Colors.secondary)
            } else {
                Picker("Language", selection: $selected) {
                    ForEach(availableLanguages) { lang in
                        Text(lang.label).tag(lang)
                    }
                }
                .onAppear { if let first = availableLanguages.first { selected = first } }
            }
            HStack {
                Button("Cancel") { dismiss() }.keyboardShortcut(.cancelAction)
                Spacer()
                Button("Add") {
                    onAdd(TranslationLanguage(
                        code: selected.rawValue, label: selected.label,
                        modifier: .control, key: selected.defaultKey
                    ))
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(availableLanguages.isEmpty)
            }
        }
        .padding(DS.Spacing.xl)
        .frame(width: 300)
    }
}
#endif
