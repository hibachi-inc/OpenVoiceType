#if PROFEATURES
import SwiftUI

struct CustomRefineSettingsView: View {
    @State private var prefs = PreferencesStore.shared

    private var isLocked: Bool { !ProUpgradeManager.shared.isPro }

    var body: some View {
        Form {
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
                    .frame(height: 110)
                    .scrollContentBackground(.hidden)
                    .background(DS.Colors.fieldBg)
                    .clipShape(RoundedRectangle(cornerRadius: 4))
                    .overlay(
                        RoundedRectangle(cornerRadius: 4)
                            .stroke(DS.Colors.secondary.opacity(0.3))
                    )

                HStack {
                    Text("refinement.default_prompt_desc_pro")
                        .font(DS.Font.caption)
                        .foregroundStyle(DS.Colors.secondary)

                    Spacer()

                    Button("refinement.default_prompt.reset", systemImage: "arrow.counterclockwise") {
                        prefs.resetDefaultPrompt()
                    }
                    .disabled(!prefs.isDefaultPromptCustomized)
                    .controlSize(.small)
                }
            }

            Section("refinement.type_prompts") {
                if isLocked {
                    VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                        Label("pro.upgrade_hint_custom_refine", systemImage: "lock.fill")
                            .font(DS.Font.caption)
                            .foregroundStyle(DS.Colors.darkCoffee)

                        Button("pro.open_upgrade") {
                            NotificationCenter.default.post(name: .openProSettings, object: nil)
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                    }
                }

                CategoryPromptEditor()
                    .disabled(isLocked)

                Text("refinement.type_prompts_desc")
                    .font(DS.Font.caption)
                    .foregroundStyle(DS.Colors.secondary)
            }

            Section("refinement.app_prompts") {
                AppSpecificPromptEditor()
                    .disabled(isLocked)

                Text("refinement.app_prompts_desc")
                    .font(DS.Font.caption)
                    .foregroundStyle(DS.Colors.secondary)
            }
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
        .background(DS.Colors.windowBg)
        .navigationTitle(String(localized: "sidebar.custom_refine"))
    }
}
#endif
