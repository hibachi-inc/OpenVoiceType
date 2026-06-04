#if PROFEATURES
import SwiftUI

struct CustomRefineSettingsView: View {
    @State private var prefs = PreferencesStore.shared

    private var isLocked: Bool { !ProUpgradeManager.shared.isPro }

    var body: some View {
        Form {
            if isLocked {
                Section {
                    Label("pro.upgrade_hint_custom_refine", systemImage: "lock.fill")
                        .font(DS.Font.caption)
                        .foregroundStyle(DS.Colors.darkCoffee)
                }
            }

            Section("refinement.app_prompts") {
                AppPromptEditor()
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
