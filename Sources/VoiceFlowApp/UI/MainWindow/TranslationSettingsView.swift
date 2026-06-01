#if PROFEATURES
import SwiftUI

struct TranslationSettingsView: View {
    @State private var prefs = PreferencesStore.shared
    @State private var showingAddSheet = false

    var body: some View {
        Form {
            Section("translation.enabled") {
                if prefs.translationLanguages.isEmpty {
                    Text("translation.empty")
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
                Button("translation.add") { showingAddSheet = true }
            }

            Section("translation.how_it_works") {
                Text("translation.how_it_works_desc")
                    .font(DS.Font.caption)
                    .foregroundStyle(DS.Colors.secondary)
            }
        }
        .formStyle(.grouped)
        .navigationTitle(String(localized: "sidebar.translation"))
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
            Text("translation.add_title").font(DS.Font.headline)
            if availableLanguages.isEmpty {
                Text("translation.all_enabled")
                    .foregroundStyle(DS.Colors.secondary)
            } else {
                Picker("translation.language", selection: $selected) {
                    ForEach(availableLanguages) { lang in
                        Text(lang.label).tag(lang)
                    }
                }
                .onAppear { if let first = availableLanguages.first { selected = first } }
            }
            HStack {
                Button("translation.cancel") { dismiss() }.keyboardShortcut(.cancelAction)
                Spacer()
                Button("translation.add_button") {
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
